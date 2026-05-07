# External Secrets Operator (ESO)

## Overview
This directory contains manifests and scripts to install and configure 
the External Secrets Operator on the EKS cluster.

## What it does
- Installs ESO via Helm into the `external-secrets` namespace
- Configures a ClusterSecretStore pointing to AWS Secrets Manager
- Creates a test ExternalSecret that pulls `petclinic/dev/db-password`
  from AWS Secrets Manager and creates a Kubernetes secret automatically

## Prerequisites
- EKS cluster running and kubectl configured
- Helm 3 installed
- AWS IAM role with Secrets Manager read access
- IRSA (IAM Roles for Service Accounts) configured on the cluster

## Installation
```bash
./external-secrets/install-eso.sh
```

## Verify
```bash
# Check ESO pods are running
kubectl get pods -n external-secrets

# Check ExternalSecret status
kubectl get externalsecret -n default

# Check the Kubernetes secret was created automatically
kubectl get secret petclinic-test-secret -n default
```
