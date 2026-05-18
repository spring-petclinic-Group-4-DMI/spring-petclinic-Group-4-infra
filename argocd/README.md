# ArgoCD Applications

## Overview
This directory contains ArgoCD Application manifests for the deployed
PetClinic services. Each application points to its corresponding
Helm chart in the /helm folder and syncs automatically when changes
are detected.

## Services
- config-server
- discovery-server
- api-gateway
- customers-service
- vets-service
- visits-service
- genai-service
- admin-server
- db-migrations

## Sync Policy
All applications are configured with:
- Automated sync — triggers on any Git change detected
- Self-healing — ArgoCD corrects any manual cluster changes
- Auto-pruning — removes resources deleted from Git
- Retry with backoff — 3 retries with exponential backoff

## Apply all manifests
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/

## Verify
kubectl get applications -n argocd

Testing the ArgoCD applications can be done by making a change to one of the Helm charts in the /helm directory, such as updating the image tag for a service. Once the change is committed and pushed to the Git repository, ArgoCD will automatically detect the change and sync the application. You can verify that the application has been updated by checking the ArgoCD dashboard or by running `kubectl get applications -n argocd` to see the status of each application.