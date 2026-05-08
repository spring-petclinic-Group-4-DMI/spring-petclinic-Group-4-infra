# Staging Deployment Runbook

## Overview
This runbook documents the first full deployment of all 9 PetClinic 
microservices to the staging environment via ArgoCD.

## Prerequisites
- kubectl configured and pointing to the staging EKS cluster
- ArgoCD CLI installed and logged in
- All 9 ArgoCD Application manifests applied to the cluster

## Deployment Order
Services must start in this exact order due to dependencies:

1. **config-server** — must be fully healthy first
   - All other services fetch config from here on startup
2. **discovery-server** — must be healthy before business services
   - All services register here (Eureka)
3. **Business services** — can start in parallel
   - customers-service
   - vets-service
   - visits-service
   - genai-service
   - admin-server
   - frontend
4. **api-gateway** — must start absolutely last
   - Routes traffic to all registered services

## Run the Deployment
```bash
./deployment/scripts/deploy-staging.sh
```

## Verify the Deployment
```bash
./deployment/scripts/verify-staging.sh
```

## Manual Verification Steps

### 1. ArgoCD UI
- Open the ArgoCD UI
- All 9 apps must show status: Healthy | Synced

### 2. Eureka Dashboard
- All 9 services must appear as registered instances

### 3. PetClinic Frontend
- Frontend must load successfully at the staging URL

### 4. kubectl checks
```bash
# All pods running
kubectl get pods -n petclinic-staging

# All services exist
kubectl get svc -n petclinic-staging

# Check logs if any pod has issues
kubectl logs -l app=config-server -n petclinic-staging
kubectl logs -l app=discovery-server -n petclinic-staging
```

## Acceptance Criteria
- [ ] ArgoCD shows all 9 apps as Healthy and Synced
- [ ] All 9 services visible in Eureka dashboard
- [ ] PetClinic frontend accessible via staging URL
