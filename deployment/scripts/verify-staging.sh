#!/bin/bash

NAMESPACE="petclinic-staging"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local description=$1
  local command=$2

  if eval "$command" > /dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC} $description"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}[FAIL]${NC} $description"
    FAIL=$((FAIL + 1))
  fi
}

echo "================================================"
echo "  Staging Verification Checks"
echo "================================================"

echo ""
echo "--- ArgoCD Application Health ---"
for app in config-server discovery-server api-gateway \
           customers-service vets-service visits-service \
           genai-service admin-server frontend; do
  check "$app is Healthy and Synced" \
    "argocd app get $app --output json | python3 -c \
    \"import sys,json; d=json.load(sys.stdin); \
    h=d['status']['health']['status']; \
    s=d['status']['sync']['status']; \
    exit(0 if h=='Healthy' and s=='Synced' else 1)\""
done

echo ""
echo "--- Pod Readiness ---"
for app in config-server discovery-server api-gateway \
           customers-service vets-service visits-service \
           genai-service admin-server frontend; do
  check "$app pods running" \
    "kubectl get pods -n $NAMESPACE -l app=$app \
    --field-selector=status.phase=Running | grep -q Running"
done

echo ""
echo "--- Service Endpoints ---"
check "config-server service exists" \
  "kubectl get svc config-server -n $NAMESPACE"
check "discovery-server service exists" \
  "kubectl get svc discovery-server -n $NAMESPACE"
check "api-gateway service exists" \
  "kubectl get svc api-gateway -n $NAMESPACE"

echo ""
echo "================================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "================================================"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All checks passed! Staging deployment verified.${NC}"
  exit 0
else
  echo -e "${RED}Some checks failed. Review above output.${NC}"
  exit 1
fi
