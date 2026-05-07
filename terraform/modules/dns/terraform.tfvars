# terraform.tfvars.example
# Copy this file to terraform.tfvars and fill in your real values.
# terraform.tfvars is gitignored — never commit real values.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # edit terraform.tfvars
#   terraform init -backend-config="bucket=petclinic-group4-tfstate" \
#                  -backend-config="key=dns/terraform.tfstate"       \
#                  -backend-config="region=us-east-1"                \
#                  -backend-config="dynamodb_table=petclinic-group4-tflock"
#   terraform plan
#   terraform apply

# AWS region — must match where your ALBs were provisioned in SPC-005-T8.
aws_region = "us-east-1"

# Apex domain for the Route 53 hosted zone.
# After the first terraform apply, copy the name_servers output to your
# domain registrar (e.g. Namecheap, GoDaddy) to delegate DNS to Route 53.
domain_name = "petclinic-group4.com"

# Name of the staging ALB as shown in the AWS EC2 > Load Balancers console,
# or as set by the Name tag / name attribute in the SPC-005-T8 Terraform.
staging_alb_name = "petclinic-staging-alb"

# Name of the production ALB. Only required when create_prod_records = true.
prod_alb_name = "petclinic-prod-alb"

# Set to false for this sprint (staging only).
# Flip to true once the production ALB is provisioned in a later sprint.
create_prod_records = false

# Tags applied to every resource. Extend as needed for your team conventions.
default_tags = {
  Project   = "spring-petclinic"
  Team      = "group-4"
  ManagedBy = "terraform"
  Epic      = "SPC-005"
  Ticket    = "SPC-005-T9"
}
