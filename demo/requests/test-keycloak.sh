#!/bin/bash

# Test Keycloak health and functionality for BST demo
# Comprehensive diagnostics with clear error messages for SEs

set -o pipefail

REALM="bst-demo"
KEYCLOAK_PORT="18080"
KEYCLOAK_URL="http://localhost:${KEYCLOAK_PORT}"

PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC} BST Demo — Keycloak Health & Configuration Test         ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Logging functions
print_step() {
    echo -e "${CYAN}→${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

print_error() {
    echo -e "${RED}ERROR${NC}: $1"
}

print_info() {
    echo "  $1"
}

decode_jwt() {
    local jwt=$1
    local payload=$(echo "$jwt" | cut -d'.' -f2)
    # Add padding
    case $((${#payload} % 4)) in
        2) payload="${payload}==" ;;
        3) payload="${payload}=" ;;
    esac
    echo "$payload" | base64 -d 2>/dev/null || echo "Failed to decode JWT"
}

# =============================================================================
# STEP 1: Check for Keycloak pod
# =============================================================================
echo -e "${BLUE}[1/5] Checking for Keycloak pod${NC}"
print_step "Looking for pods in keycloak namespace with label app=keycloak"

KEYCLOAK_PODS=$(kubectl get pods -n keycloak -l app=keycloak -o jsonpath='{.items[*].metadata.name}' 2>&1)
KUBECTL_EXIT=$?

if [ $KUBECTL_EXIT -ne 0 ]; then
    print_fail "kubectl command failed"
    print_error "Unable to list pods. Is kubectl configured? Can you access the cluster?"
    print_info "Error output: $KEYCLOAK_PODS"
    echo ""
    exit 1
fi

if [ -z "$KEYCLOAK_PODS" ]; then
    print_fail "No Keycloak pods found in keycloak namespace"
    print_error "Keycloak is not deployed. Deploy it with:"
    print_info "  kubectl apply -f k8s/keycloak/keycloak.yaml"
    echo ""
    exit 1
fi

KEYCLOAK_POD=$(echo "$KEYCLOAK_PODS" | awk '{print $1}')
print_pass "Found Keycloak pod: $KEYCLOAK_POD"
echo ""

# =============================================================================
# STEP 2: Wait for pod to be ready
# =============================================================================
echo -e "${BLUE}[2/5] Waiting for Keycloak pod to be ready${NC}"
print_step "Checking pod status..."
print_info "Note: Initial startup with realm import can take 30-60 seconds"

POD_STATUS=$(kubectl get pod -n keycloak "$KEYCLOAK_POD" -o jsonpath='{.status.phase}' 2>&1)

if [ "$POD_STATUS" != "Running" ]; then
    print_fail "Pod is in $POD_STATUS state (expected Running)"
    print_step "Waiting up to 120 seconds for pod to be ready..."

    TIMEOUT=120
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        POD_STATUS=$(kubectl get pod -n keycloak "$KEYCLOAK_POD" -o jsonpath='{.status.phase}' 2>&1)
        READY=$(kubectl get pod -n keycloak "$KEYCLOAK_POD" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>&1)

        if [ "$POD_STATUS" = "Running" ] && [ "$READY" = "True" ]; then
            print_pass "Pod is running and ready"
            break
        fi

        REMAINING=$((TIMEOUT - ELAPSED))
        echo -ne "  Status: $POD_STATUS, Ready: $READY — waiting... (${REMAINING}s remaining)\r"
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done

    if [ "$POD_STATUS" != "Running" ] || [ "$READY" != "True" ]; then
        print_fail "Pod did not become ready within timeout"
        print_error "Pod status: $POD_STATUS | Ready condition: $READY"
        print_info "Recent pod events:"
        kubectl describe pod -n keycloak "$KEYCLOAK_POD" 2>&1 | tail -20 | sed 's/^/    /'
        echo ""
        exit 1
    fi
else
    print_pass "Pod is running"
fi
echo ""

# =============================================================================
# STEP 3: Port-forward and test reachability
# =============================================================================
echo -e "${BLUE}[3/5] Setting up port-forward to Keycloak${NC}"
print_step "Forwarding local port $KEYCLOAK_PORT to Keycloak pod port 8080"
print_info "Command: kubectl port-forward -n keycloak pod/$KEYCLOAK_POD $KEYCLOAK_PORT:8080"

kubectl port-forward -n keycloak "pod/$KEYCLOAK_POD" "$KEYCLOAK_PORT:8080" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Give port-forward time to establish
sleep 2

# Verify port-forward is working by testing realm endpoint
print_step "Testing connection to $KEYCLOAK_URL by accessing realm..."
print_info "Endpoint: GET $KEYCLOAK_URL/realms/$REALM"
print_info "Note: Using realm endpoint to verify Keycloak is responding (health endpoints not available)"

# Make a quick request to the realm endpoint to verify connectivity
curl -s "$KEYCLOAK_URL/realms/$REALM" > /dev/null 2>&1
CONNECTIVITY_CHECK=$?

if [ $CONNECTIVITY_CHECK -ne 0 ]; then
    print_fail "Could not reach Keycloak at $KEYCLOAK_URL"
    print_error "Unable to connect via port-forward"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    echo ""
    exit 1
fi

print_pass "Keycloak is reachable and responding"
echo ""

# =============================================================================
# STEP 4: Test realm configuration
# =============================================================================
echo -e "${BLUE}[4/5] Testing realm configuration${NC}"
print_step "Fetching realm metadata from GET $KEYCLOAK_URL/realms/$REALM"
print_info "Keycloak 24.x endpoint format (no /auth prefix)"

REALM_RESPONSE=$(curl -s -w "\n%{http_code}" "$KEYCLOAK_URL/realms/$REALM" 2>&1)
CURL_EXIT=$?
HTTP_CODE=$(echo "$REALM_RESPONSE" | tail -1)
BODY=$(echo "$REALM_RESPONSE" | sed '$d')

if [ $CURL_EXIT -ne 0 ]; then
    print_fail "curl command failed (exit code: $CURL_EXIT)"
    print_error "Response body:"
    echo "$BODY" | sed 's/^/    /'
    kill $PORT_FORWARD_PID 2>/dev/null || true
    echo ""
    exit 1
fi

if [ "$HTTP_CODE" != "200" ]; then
    print_fail "Realm endpoint returned HTTP $HTTP_CODE (expected 200)"
    print_error "Response body:"
    echo "$BODY" | sed 's/^/    /'
    kill $PORT_FORWARD_PID 2>/dev/null || true
    echo ""
    exit 1
fi

# Verify we got valid JSON with a realm name
REALM_NAME=$(echo "$BODY" | jq -r '.realm' 2>/dev/null)
if [ -z "$REALM_NAME" ] || [ "$REALM_NAME" = "null" ]; then
    print_fail "Realm response does not contain valid realm name"
    print_error "Response body:"
    echo "$BODY" | jq . 2>/dev/null | sed 's/^/    /'
    kill $PORT_FORWARD_PID 2>/dev/null || true
    echo ""
    exit 1
fi

print_pass "Realm '$REALM_NAME' exists and is configured"
echo ""

# =============================================================================
# STEP 5: Test client token generation
# =============================================================================
echo -e "${BLUE}[5/5] Testing client token generation${NC}"

TOKEN_ENDPOINT="$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token"

# Define service account clients (demo-client is public and uses different grant type)
print_info "Testing service account clients with client_credentials grant"
CLIENTS="scheduling-agent:scheduling-agent-secret-456 booking-agent:booking-agent-secret-789"

for CLIENT_PAIR in $CLIENTS; do
    CLIENT_ID=$(echo "$CLIENT_PAIR" | cut -d: -f1)
    CLIENT_SECRET=$(echo "$CLIENT_PAIR" | cut -d: -f2)

    print_step "Testing client: $CLIENT_ID"
    print_info "POST $TOKEN_ENDPOINT"
    print_info "  client_id=$CLIENT_ID"
    print_info "  grant_type=client_credentials"

    TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TOKEN_ENDPOINT" \
        -d "client_id=${CLIENT_ID}" \
        -d "client_secret=${CLIENT_SECRET}" \
        -d "grant_type=client_credentials" 2>&1)

    CURL_EXIT=$?
    HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -1)
    BODY=$(echo "$TOKEN_RESPONSE" | sed '$d')

    if [ $CURL_EXIT -ne 0 ]; then
        print_fail "curl command failed for $CLIENT_ID (exit code: $CURL_EXIT)"
        print_error "Response body:"
        echo "$BODY" | sed 's/^/      /'
        ((FAIL_COUNT++))
        echo ""
        continue
    fi

    if [ "$HTTP_CODE" != "200" ]; then
        print_fail "$CLIENT_ID: Token request returned HTTP $HTTP_CODE"
        ERROR_DESC=$(echo "$BODY" | jq -r '.error_description // .error // "Unknown error"' 2>/dev/null)
        print_error "Error: $ERROR_DESC"
        print_info "Full response:"
        echo "$BODY" | jq . 2>/dev/null | sed 's/^/      /'
        echo ""
        continue
    fi

    # Extract and validate token
    TOKEN=$(echo "$BODY" | jq -r '.access_token' 2>/dev/null)
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        print_fail "$CLIENT_ID: No access_token in response"
        print_info "Full response:"
        echo "$BODY" | jq . 2>/dev/null | sed 's/^/      /'
        echo ""
        continue
    fi

    print_pass "$CLIENT_ID: Valid JWT token obtained"

    # Decode and display claims
    print_info "JWT Claims:"
    CLAIMS=$(decode_jwt "$TOKEN")
    echo "$CLAIMS" | jq . 2>/dev/null | sed 's/^/    /'
    echo ""
done

# Cleanup port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# =============================================================================
# SUMMARY
# =============================================================================
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ $TOTAL -eq 0 ]; then
    echo -e "${RED}No tests were run${NC}"
    exit 1
fi

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}═══ Results: $PASS_COUNT/$TOTAL PASSED ===${NC}"
    echo -e "\n${GREEN}✓ Keycloak is fully operational. Ready for demo.${NC}\n"
    exit 0
else
    echo -e "${RED}═══ Results: $PASS_COUNT/$TOTAL PASSED — $FAIL_COUNT failed ===${NC}"
    echo -e "\n${RED}✗ Fix errors above before proceeding.${NC}\n"
    exit 1
fi
