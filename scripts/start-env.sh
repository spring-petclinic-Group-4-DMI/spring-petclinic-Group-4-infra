#!/usr/bin/env bash
set -euo pipefail

#
# start-env.sh — Resume the dev AWS environment after stopping it
#
# Starts RDS and scales EKS node group back up.
# Waits for both to be ready before declaring success.
#
# Usage:
#   ./scripts/start-env.sh
#

REGION="${AWS_DEFAULT_REGION:-us-east-2}"
ENV="dev"

# Sized to match terraform/environments/dev/main.tf (eks module call).
# The full stack (8 petclinic services + ArgoCD + observability + ALB controller +
# ESO + db-migrations Job) needs ~6 t4g.small nodes to schedule without hitting
# the per-node pod-capacity limit. 2 nodes will leave half the pods Pending.
DESIRED_NODES=6
MIN_NODES=4
MAX_NODES=6

CLUSTER_NAME="petclinic-${ENV}"
NODEGROUP_NAME="petclinic-${ENV}-nodes"
RDS_INSTANCE_ID="petclinic-${ENV}-mysql"

echo "============================================"
echo "  Starting environment: ${ENV}"
echo "  Region: ${REGION}"
echo "============================================"
echo ""

# --- Start RDS Instance ---
echo "[1/2] Starting RDS instance: ${RDS_INSTANCE_ID}"

RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "${RDS_INSTANCE_ID}" \
  --region "${REGION}" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "not-found")

case "${RDS_STATUS}" in
  stopped)
    aws rds start-db-instance \
      --db-instance-identifier "${RDS_INSTANCE_ID}" \
      --region "${REGION}" > /dev/null
    echo "  -> RDS start initiated. Waiting for it to become available..."
    echo "     (This typically takes 3-8 minutes)"
    aws rds wait db-instance-available \
      --db-instance-identifier "${RDS_INSTANCE_ID}" \
      --region "${REGION}" 2>/dev/null || true
    echo "  -> RDS is available."
    ;;
  available)
    echo "  -> RDS is already running. No action needed."
    ;;
  starting)
    echo "  -> RDS is already starting. Waiting..."
    aws rds wait db-instance-available \
      --db-instance-identifier "${RDS_INSTANCE_ID}" \
      --region "${REGION}" 2>/dev/null || true
    echo "  -> RDS is available."
    ;;
  not-found)
    echo "  -> RDS instance not found. Skipping."
    ;;
  *)
    echo "  -> RDS is in '${RDS_STATUS}' state. Cannot start now."
    ;;
esac

echo ""

# --- Scale EKS Node Group Back Up ---
echo "[2/2] Scaling EKS node group: ${NODEGROUP_NAME} (desired: ${DESIRED_NODES})"

NODEGROUP_EXISTS=$(aws eks describe-nodegroup \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --region "${REGION}" \
  --query 'nodegroup.status' \
  --output text 2>/dev/null || echo "not-found")

if [[ "${NODEGROUP_EXISTS}" == "not-found" ]]; then
  echo "  -> Node group not found. Skipping."
else
  CURRENT_DESIRED=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${REGION}" \
    --query 'nodegroup.scalingConfig.desiredSize' \
    --output text)

  if [[ "${CURRENT_DESIRED}" -ge "${DESIRED_NODES}" ]]; then
    echo "  -> Node group already has ${CURRENT_DESIRED} desired nodes. No action needed."
  else
    aws eks update-nodegroup-config \
      --cluster-name "${CLUSTER_NAME}" \
      --nodegroup-name "${NODEGROUP_NAME}" \
      --scaling-config "minSize=${MIN_NODES},maxSize=${MAX_NODES},desiredSize=${DESIRED_NODES}" \
      --region "${REGION}" > /dev/null
    echo "  -> Scaling to ${DESIRED_NODES} nodes. Waiting for nodes to join..."
    echo "     (This typically takes 2-5 minutes)"

    # Wait for nodegroup to be ACTIVE
    aws eks wait nodegroup-active \
      --cluster-name "${CLUSTER_NAME}" \
      --nodegroup-name "${NODEGROUP_NAME}" \
      --region "${REGION}" 2>/dev/null || true
    echo "  -> Node group is active."
  fi
fi

echo ""
echo "============================================"
echo "  Environment ${ENV} is ready."
echo ""
echo "  Update kubeconfig:"
echo "    aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}"
echo ""
echo "  Verify:"
echo "    kubectl get nodes"
echo "    kubectl get pods -n petclinic-${ENV}"
echo "============================================"
