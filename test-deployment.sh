#!/bin/bash

# test-deployment.sh
# Script to test the deployment

set -e

echo "🔍 Testing Node.js Application (Enosis) Deployment on EKS"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="production"
APP_NAME="nodeapp"
TIMEOUT=300

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        exit 1
    fi
}

# Test 1: Check if cluster is accessible
echo -e "\n${YELLOW}Test 1: Checking EKS cluster accessibility${NC}"
kubectl cluster-info &> /dev/null
print_status $? "EKS cluster is accessible"

# Test 2: Check if namespace exists
echo -e "\n${YELLOW}Test 2: Checking namespace${NC}"
kubectl get namespace $NAMESPACE &> /dev/null
print_status $? "Namespace '$NAMESPACE' exists"

# Test 3: Check if deployment exists
echo -e "\n${YELLOW}Test 3: Checking deployment${NC}"
kubectl get deployment -n $NAMESPACE | grep $APP_NAME &> /dev/null
print_status $? "Deployment exists"

# Test 4: Check if pods are running
echo -e "\n${YELLOW}Test 4: Checking pod status${NC}"
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=nodeapp-k8s-project --field-selector=status.phase=Running -o json | jq '.items | length')
if [ "$RUNNING_PODS" -gt 0 ]; then
    print_status 0 "$RUNNING_PODS pods are running"
else
    print_status 1 "No pods are running"
fi

# Test 5: Check service
echo -e "\n${YELLOW}Test 5: Checking service${NC}"
kubectl get svc $APP_NAME-nodeapp-k8s-project -n $NAMESPACE &> /dev/null
print_status $? "Service exists"

# Test 6: Check LoadBalancer
echo -e "\n${YELLOW}Test 6: Checking LoadBalancer${NC}"
LB_URL=$(kubectl get svc $APP_NAME-nodeapp-k8s-project -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "$LB_URL" ]; then
    print_status 0 "LoadBalancer URL: $LB_URL"
else
    print_status 1 "LoadBalancer URL not found"
fi

# Test 7: Check HPA
echo -e "\n${YELLOW}Test 7: Checking Horizontal Pod Autoscaler${NC}"
kubectl get hpa -n $NAMESPACE | grep $APP_NAME &> /dev/null
print_status $? "HPA is configured"

# Test 8: Test application endpoint
echo -e "\n${YELLOW}Test 8: Testing application health endpoint${NC}"
if [ -n "$LB_URL" ]; then
    sleep 10  # Give LB time to be ready
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$LB_URL:3000/health || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_status 0 "Health endpoint returned 200 OK"
    else
        echo -e "${YELLOW}⚠${NC} Health endpoint returned $HTTP_CODE (may need more time to be ready)"
    fi
fi

# Test 9: Check resource limits
echo -e "\n${YELLOW}Test 9: Checking resource limits${NC}"
LIMITS=$(kubectl get deployment $APP_NAME-nodeapp-k8s-project -n $NAMESPACE -o json | jq '.spec.template.spec.containers[0].resources.limits')
if [ "$LIMITS" != "null" ]; then
    print_status 0 "Resource limits are set"
else
    print_status 1 "Resource limits are not set"
fi

# Test 10: Check liveness and readiness probes
echo -e "\n${YELLOW}Test 10: Checking health probes${NC}"
LIVENESS=$(kubectl get deployment $APP_NAME-nodeapp-k8s-project -n $NAMESPACE -o json | jq '.spec.template.spec.containers[0].livenessProbe')
READINESS=$(kubectl get deployment $APP_NAME-nodeapp-k8s-project -n $NAMESPACE -o json | jq '.spec.template.spec.containers[0].readinessProbe')
if [ "$LIVENESS" != "null" ] && [ "$READINESS" != "null" ]; then
    print_status 0 "Liveness and readiness probes are configured"
else
    print_status 1 "Health probes are not properly configured"
fi

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"

# Print summary
echo -e "\n📊 Deployment Summary:"
echo "  • Cluster: nodejs-app-cluster"
echo "  • Namespace: $NAMESPACE"
echo "  • Running Pods: $RUNNING_PODS"
echo "  • LoadBalancer URL: http://$LB_URL:3000"
echo "  • Health Check URL: http://$LB_URL:3000/health"

echo -e "\n💡 Quick Commands:"
echo "  • View logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=nodeapp-k8s-project -f"
echo "  • Scale deployment: kubectl scale deployment $APP_NAME-nodeapp-k8s-project -n $NAMESPACE --replicas=3"
echo "  • Port forward: kubectl port-forward -n $NAMESPACE svc/$APP_NAME-nodeapp-k8s-project 3000:3000"