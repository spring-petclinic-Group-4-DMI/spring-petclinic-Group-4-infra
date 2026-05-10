# Secrets Rotation — SPC-57

## What is rotated
Secret: spc-staging-ue1-app-secret
Type: RDS MySQL credentials (username + password)
Managed by: AWS Secrets Manager

## Rotation schedule
Automatic rotation: every 30 days
Lambda function: AWS managed RDS MySQL rotation function

## How it works end to end
1. Secrets Manager triggers Lambda every 30 days automatically
2. Lambda generates a new strong password
3. Lambda updates the RDS MySQL database with the new password
4. Lambda updates the secret value in Secrets Manager
5. External Secrets Operator (ESO) polls Secrets Manager every 1 hour
6. ESO detects the new secret version and updates the Kubernetes secret
7. Spring Boot HikariCP connection pool picks up new credentials
8. Zero downtime — existing connections drain naturally

## How to enable rotation (done once)
aws secretsmanager rotate-secret \
  --secret-id spc-staging-ue1-app-secret \
  --rotation-rules AutomaticallyAfterDays=30 \
  --region us-east-1 \
  --profile terraform

## How to trigger manual rotation
aws secretsmanager rotate-secret \
  --secret-id spc-staging-ue1-app-secret \
  --region us-east-1 \
  --profile terraform

## How to verify rotation worked
aws secretsmanager describe-secret \
  --secret-id spc-staging-ue1-app-secret \
  --region us-east-1 \
  --profile terraform \
  --query '[RotationEnabled,LastRotatedDate,NextRotationDate]'

## Zero downtime verification
After manual rotation:
  kubectl get pods -n petclinic | grep -E 'customers|vets|visits'
  All must show STATUS: Running READY: 1/1

## Status
Rotation enabled on: PENDING — waiting for SPC-39 (RDS) to be provisioned
Manual rotation verified on: PENDING
Zero downtime confirmed: PENDING
