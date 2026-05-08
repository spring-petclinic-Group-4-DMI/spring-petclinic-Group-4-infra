#!/bin/bash
set -e

NAMESPACE="petclinic-staging"
ARGOCD_NAMESPACE="argocd"

echo "================================================"
echo "  PetClinic Staging Full Deployment"
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to wait for ArgoCD app to be Healthy and Synced
wait_for_app() {
  local app=$1
  local timeout=${2:-300}
  local interval=10
  local elapsed=0

  log_info "Waiting for $app to be Healthy and Synced..."

  while [ $elapsed -lt $timeout ]; do
    STATUS=$(argocd app get "$app" --output json 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); \
      print(d['status']['health']['status'], d['status']['sync']['status'])" \
      2>/dev/null || echo "Unknown Unknown")

    HEALTH=$(echo $STATUS | awk '{print $1}')
    SYNC=$(echo $STATUS | awk '{print $2}')

    if [ "$HEALTH" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
      log_info "$app is Healthy and Synced"
      return 0
    fi

    log_warning "$app status: Health=$HEALTH Sync=$SYNC - waiting..."
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  log_error "$app did not become healthy within ${timeout}s"
  return 1
}

# Function to wait for pod readiness
wait_for_pods() {
  local app=$1
  log_info "Waiting for $app pods to be ready..."
  kubectl wait --for=condition=ready pod \
    -l app="$app" \
    -n "$NAMESPACE" \
    --timeout=300s
  log_info "$app pods are ready"
}

echo ""
log_info "Creating namespace if not exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "================================================"
echo "  STEP 1: Syncing config-server (FIRST)"
echo "================================================"
argocd app sync config-server --timeout 120
wait_for_app config-server
wait_for_pods config-server

echo ""
echo "================================================"
echo "  STEP 2: Syncing discovery-server (SECOND)"
echo "================================================"
argocd app sync discovery-server --timeout 120
wait_for_app discovery-server
wait_for_pods discovery-server

echo ""
echo "================================================"
echo "  STEP 3: Syncing business services (PARALLEL)"
echo "================================================"
argocd app sync customers-service --timeout 120 &
argocd app sync vets-service --timeout 120 &
argocd app sync visits-service --timeout 120 &
argocd app sync genai-service --timeout 120 &
argocd app sync admin-server --timeout 120 &
argocd app sync frontend --timeout 120 &
wait

wait_for_app customers-service
wait_for_app vets-service
wait_for_app visits-service
wait_for_app genai-service
wait_for_app admin-server
wait_for_app frontend

echo ""
echo "================================================"
echo "  STEP 4: Syncing api-gateway (LAST)"
echo "================================================"
argocd app sync api-gateway --timeout 120
wait_for_app api-gateway
wait_for_pods api-gateway

echo ""
echo "================================================"
echo "  VERIFICATION"
echo "================================================"

log_info "Checking all ArgoCD applications..."
argocd app list

echo ""
log_info "Checking all pods in $NAMESPACE..."
kubectl get pods -n "$NAMESPACE"

echo ""
log_info "Checking all services..."
kubectl get svc -n "$NAMESPACE"

echo ""
echo "================================================"
echo "  DEPLOYMENT COMPLETE"
echo "================================================"
log_info "All 9 services deployed to staging"
log_info "Check Eureka dashboard for service registration"
log_info "Check ArgoCD UI - all apps should show Healthy and Synced"
