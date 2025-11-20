#!/bin/bash
# Integration test suite for AKS Demo
# Tests the deployed application end-to-end

set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

run_test() {
    ((TESTS_RUN++))
    echo ""
    log_info "Test $TESTS_RUN: $1"
}

# Main test suite
main() {
    echo "=========================================="
    echo "  AKS Demo Integration Test Suite"
    echo "=========================================="
    echo ""

    # Get service endpoint
    log_info "Retrieving service endpoint..."
    IP=$(kubectl get svc aks-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [ -z "$IP" ]; then
        log_error "Service IP not found. Is the service deployed?"
        exit 1
    fi

    ENDPOINT="http://$IP"
    log_info "Testing endpoint: $ENDPOINT"
    echo ""

    # Test 1: Basic connectivity
    run_test "Basic HTTP connectivity"
    if curl -sS "$ENDPOINT/" --connect-timeout 5 --max-time 10 > /tmp/curl_test_$$ 2>&1; then
        log_success "Endpoint is reachable"
        rm -f /tmp/curl_test_$$
    else
        log_error "Cannot reach endpoint"
        rm -f /tmp/curl_test_$$
        exit 1
    fi

    # Test 2: Response structure validation
    run_test "Response structure validation"
    RESPONSE=$(curl -sS "$ENDPOINT/" --connect-timeout 5 --max-time 10)
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message' 2>/dev/null || echo "")
    TIMESTAMP=$(echo "$RESPONSE" | jq -r '.timestamp' 2>/dev/null || echo "")

    if [ "$MESSAGE" = "Automate all the things!" ] && [ "$TIMESTAMP" -gt 0 ] 2>/dev/null; then
        log_success "Response structure is valid"
        log_info "  Message: $MESSAGE"
        log_info "  Timestamp: $TIMESTAMP"
    else
        log_error "Invalid response structure"
        log_info "  Response: $RESPONSE"
        exit 1
    fi

    # Test 3: Timestamp accuracy
    run_test "Timestamp accuracy check"
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - TIMESTAMP))
    ABS_TIME_DIFF=${TIME_DIFF#-}  # Absolute value

    if [ "$ABS_TIME_DIFF" -lt 10 ]; then
        log_success "Timestamp is accurate (within 10 seconds)"
        log_info "  Time difference: ${TIME_DIFF}s"
    else
        log_error "Timestamp is inaccurate (off by ${TIME_DIFF}s)"
    fi

    # Test 4: Health endpoint
    run_test "Health endpoint check"
    HEALTH_RESPONSE=$(curl -sS "$ENDPOINT/health" --connect-timeout 5 --max-time 10 2>/dev/null || echo "{}")
    HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status' 2>/dev/null || echo "")

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        log_success "Health endpoint returns healthy status"
    else
        log_error "Health endpoint not responding correctly"
        log_info "  Response: $HEALTH_RESPONSE"
    fi

    # Test 5: Response time performance
    run_test "Response time performance"
    TEMP_OUT=$(mktemp)
    RESPONSE_TIME=$(curl -sS "$ENDPOINT/" -o "$TEMP_OUT" -w '%{time_total}' --connect-timeout 5 --max-time 10 2>/dev/null || echo "999")
    rm -f "$TEMP_OUT"
    RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc 2>/dev/null || echo "9999")

    if (( $(echo "$RESPONSE_TIME < 0.5" | bc -l) )); then
        log_success "Response time is acceptable: ${RESPONSE_MS}ms"
    else
        log_error "Response time is too slow: ${RESPONSE_MS}ms (should be < 500ms)"
    fi

    # Test 6: Kubernetes pod health
    run_test "Kubernetes pod health check"
    READY_PODS=$(kubectl get pods -l app=aks-demo --field-selector=status.phase=Running -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')
    TOTAL_PODS=$(kubectl get pods -l app=aks-demo -o json | jq '.items | length')

    if [ "$READY_PODS" -ge 1 ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        log_success "All pods are healthy ($READY_PODS/$TOTAL_PODS ready)"
    else
        log_error "Some pods are not healthy ($READY_PODS/$TOTAL_PODS ready)"
        kubectl get pods -l app=aks-demo
    fi

    # Test 7: Service endpoint configuration
    run_test "Service configuration validation"
    SVC_TYPE=$(kubectl get svc aks-demo-svc -o jsonpath='{.spec.type}')
    SVC_PORT=$(kubectl get svc aks-demo-svc -o jsonpath='{.spec.ports[0].port}')

    if [ "$SVC_TYPE" = "LoadBalancer" ] && [ "$SVC_PORT" = "80" ]; then
        log_success "Service is correctly configured"
        log_info "  Type: $SVC_TYPE"
        log_info "  Port: $SVC_PORT"
    else
        log_error "Service configuration is incorrect"
    fi

    # Test 8: High availability test (if multiple replicas)
    run_test "High availability test"
    REPLICA_COUNT=$(kubectl get deployment aks-demo -o jsonpath='{.spec.replicas}')

    if [ "$REPLICA_COUNT" -ge 2 ]; then
        log_info "Testing zero-downtime capability with $REPLICA_COUNT replicas"

        # Get one pod to delete
        POD_TO_DELETE=$(kubectl get pod -l app=aks-demo -o jsonpath='{.items[0].metadata.name}')

        # Start background requests
        log_info "  Deleting pod: $POD_TO_DELETE"
        kubectl delete pod "$POD_TO_DELETE" --wait=false >/dev/null 2>&1

        # Test availability during pod restart
        sleep 2
        SUCCESS_COUNT=0
        TEMP_OUT=$(mktemp)
        for i in {1..10}; do
            HTTP_CODE=$(curl -sS -w "%{http_code}" -o "$TEMP_OUT" --connect-timeout 2 --max-time 5 "$ENDPOINT/" 2>/dev/null || echo "000")
            if [ "$HTTP_CODE" = "200" ]; then
                ((SUCCESS_COUNT++))
            fi
            sleep 0.5
        done
        rm -f "$TEMP_OUT"

        if [ "$SUCCESS_COUNT" -ge 8 ]; then
            log_success "Service remained available during pod restart ($SUCCESS_COUNT/10 requests succeeded)"
        else
            log_error "Service had availability issues during pod restart ($SUCCESS_COUNT/10 requests succeeded)"
        fi
    else
        log_info "Skipping HA test (only $REPLICA_COUNT replica configured)"
        log_success "Test skipped (N/A for single replica)"
    fi

    # Test 9: Concurrent request handling
    run_test "Concurrent request handling"
    log_info "Sending 50 concurrent requests..."

    TEMP_FILE=$(mktemp)
    echo "0" > "$TEMP_FILE"

    for i in {1..50}; do
        (
            TEMP_OUT=$(mktemp)
            HTTP_CODE=$(curl -sS -w "%{http_code}" -o "$TEMP_OUT" --connect-timeout 3 --max-time 5 "$ENDPOINT/" 2>/dev/null || echo "000")
            rm -f "$TEMP_OUT"
            if [ "$HTTP_CODE" = "200" ]; then
                flock "$TEMP_FILE" bash -c "echo \$(($(cat "$TEMP_FILE") + 1)) > "$TEMP_FILE""
            fi
        ) &
    done
    wait
    SUCCESS=$(cat "$TEMP_FILE")
    rm -f "$TEMP_FILE"
    FAILED=$((50 - SUCCESS))

    if [ "$SUCCESS" -ge 45 ]; then
        log_success "Handled concurrent load well ($SUCCESS/50 succeeded)"
    else
        log_error "Failed to handle concurrent load ($SUCCESS/50 succeeded)"
    fi

    # Test 10: Content-Type header
    run_test "Content-Type header validation"
    CONTENT_TYPE=$(curl -sS -I "$ENDPOINT/" --connect-timeout 5 --max-time 10 | grep -i "content-type" | cut -d' ' -f2- | tr -d '\r')

    if [[ "$CONTENT_TYPE" == *"application/json"* ]]; then
        log_success "Content-Type is correct: $CONTENT_TYPE"
    else
        log_error "Content-Type is incorrect: $CONTENT_TYPE"
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "           Test Summary"
    echo "=========================================="
    echo "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
        echo ""
        echo "❌ INTEGRATION TESTS FAILED"
        exit 1
    else
        echo "Tests Failed: 0"
        echo ""
        echo "✅ ALL INTEGRATION TESTS PASSED"
        exit 0
    fi
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "Warning: bc is not installed, some tests may be skipped"
fi

# Run the test suite
main
