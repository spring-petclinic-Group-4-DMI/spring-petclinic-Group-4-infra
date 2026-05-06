#!/bin/bash
set -e

echo "Adding External Secrets Operator Helm repo..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

echo "Creating namespace..."
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

echo "Installing External Secrets Operator..."
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --values external-secrets/base/helm-values.yaml \
  --wait

echo "Applying ServiceAccount..."
kubectl apply -f external-secrets/base/service-account.yaml

echo "Applying ClusterSecretStore..."
kubectl apply -f external-secrets/base/secret-store.yaml

echo "Applying test ExternalSecret..."
kubectl apply -f external-secrets/base/external-secret.yaml

echo "Verifying ESO pods..."
kubectl get pods -n external-secrets

echo "Verifying ExternalSecret sync..."
kubectl get externalsecret petclinic-test-secret -n default
kubectl get secret petclinic-test-secret -n default

echo "Done!"
