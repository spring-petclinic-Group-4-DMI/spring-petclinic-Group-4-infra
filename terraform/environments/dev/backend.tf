# Terraform remote state backend.
#
# Activation flow (one-time):
#   1. From the repo root:  ./scripts/bootstrap-state.sh
#      Creates the S3 bucket + DynamoDB lock table in AWS.
#   2. cd terraform/environments/dev
#   3. terraform init -migrate-state    (moves existing local state to S3)
#      or just `terraform init` for a fresh setup.
#
# The bucket name embeds the AWS account ID (428101261622). If you ever deploy
# to a different account, update the bucket value here and re-run bootstrap.

terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-428101261622"
    key            = "petclinic/dev/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
