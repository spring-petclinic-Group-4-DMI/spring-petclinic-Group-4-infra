#!/usr/bin/env bash
#
# bootstrap-state.sh — One-time setup for the Terraform S3 + DynamoDB state backend.
#
# Idempotent. Run this BEFORE enabling backend.tf in terraform/environments/dev/.
# After running, run:
#   cd terraform/environments/dev
#   terraform init -migrate-state    (if you already have local state)
#   # or
#   terraform init                   (if starting fresh)
#
# Resources created:
#   - S3 bucket   petclinic-terraform-state-{account-id}   (versioning + SSE + block-public-access)
#   - DynamoDB    petclinic-terraform-locks                (LockID partition key, on-demand)
#

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-2}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="petclinic-terraform-state-${ACCOUNT_ID}"
TABLE="petclinic-terraform-locks"

echo "Region:    ${REGION}"
echo "Account:   ${ACCOUNT_ID}"
echo "Bucket:    ${BUCKET}"
echo "Lock tbl:  ${TABLE}"
echo ""

# ── S3 bucket ──────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null; then
  echo "[s3] Bucket ${BUCKET} already exists — skipping create"
else
  echo "[s3] Creating bucket ${BUCKET}..."
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi

echo "[s3] Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "[s3] Enabling default SSE-S3 encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'

echo "[s3] Blocking all public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── DynamoDB lock table ────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "[ddb] Table ${TABLE} already exists — skipping create"
else
  echo "[ddb] Creating table ${TABLE}..."
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --tags Key=Project,Value=petclinic Key=Environment,Value=dev Key=ManagedBy,Value=bootstrap-script \
    >/dev/null

  echo "[ddb] Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

echo ""
echo "Done. Next:"
echo "  1. (If you have local state already) cd terraform/environments/dev && terraform init -migrate-state"
echo "  2. (Otherwise) cd terraform/environments/dev && terraform init"
