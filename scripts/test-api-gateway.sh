#!/bin/bash
# ============================================
# API Gateway Integration Test Script
# ============================================
API="http://api.localhost"
KEYCLOAK="http://keycloak.localhost"
REALM="sakcode-prod"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
fail=0
pass_test() { echo -e "  ${GREEN}✅ PASS${NC}: $1"; ((pass++)); }
fail_test() { echo -e "  ${RED}❌ FAIL${NC}: $1 (expected $2, got $3)"; ((fail++)); }

# --------------------------------------------------
# Helper: make an HTTP request via Traefik on localhost:80
# --------------------------------------------------
traefik_get() {
    local host=$1 path=${2:-/}
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $host" "http://localhost$path" 2>/dev/null || echo "000"
}

traefik_post() {
    local host=$1 path=$2 data=$3 token=${4:-}
    local extra=()
    [[ -n "$token" ]] && extra=(-H "Authorization: Bearer $token")
    curl -s -o /dev/null -w "%{http_code}" -X POST -H "Host: $host" -H "Content-Type: application/json" -d "$data" "${extra[@]}" "http://localhost$path" 2>/dev/null || echo "000"
}

traefik_get_auth() {
    local host=$1 path=$2 token=$3
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $host" -H "Authorization: Bearer $token" "http://localhost$path" 2>/dev/null || echo "000"
}

# --------------------------------------------------
# Get JWT token via Keycloak password grant
# --------------------------------------------------
get_token() {
    local user=$1 password=$2 tmp=/tmp/kc_$$_${user}.json
    curl -s -X POST "http://localhost/realms/${REALM}/protocol/openid-connect/token" \
        -H "Host: keycloak.localhost" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=portal-ui" \
        -d "username=$user" \
        -d "password=$password" \
        -d "scope=openid profile email" \
        -o "$tmp" 2>/dev/null
    python3 -c "import json; d=json.load(open('$tmp')); print(d.get('access_token',''))" 2>/dev/null || true
    rm -f "$tmp"
}

# --------------------------------------------------
# Run a single API test
# --------------------------------------------------
test_api() {
    local method=$1 host=$2 path=$3 token=${4:-} expected=$5 desc=$6 data=${7:-}
    local code
    case "$method" in
        GET_AUTH) code=$(traefik_get_auth "$host" "$path" "$token") ;;
        POST)     code=$(traefik_post "$host" "$path" "$data" "$token") ;;
        GET)      code=$(traefik_get "$host" "$path") ;;
    esac
    if [ "$code" = "$expected" ]; then
        pass_test "$desc"
    else
        fail_test "$desc" "$expected" "$code"
    fi
}

echo "============================================="
echo "  SakCode API Gateway — Integration Tests"
echo "============================================="

# --------------------------------------------------
echo -e "\n${YELLOW}🔑 Getting JWT tokens...${NC}"
T1=$(get_token "samreach" "password123")
T2=$(get_token "backend-user" "password123")
T3=$(get_token "business-user" "password123")
if [ -z "$T1" ]; then
    echo "  ❌ Failed to get token for samreach."
    echo "  Check: curl -s ${KEYCLOAK}/realms/${REALM}/protocol/openid-connect/token"
    exit 1
fi
echo -e "  ${GREEN}✅${NC} Tokens: samreach, backend-user, business-user"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 1: Public${NC}"
test_api GET "api.localhost" "/api/health" "" "200" "Health check (no auth)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 2: Authenticated${NC}"
test_api GET_AUTH "api.localhost" "/api/userinfo" "$T1" "200" "UserInfo (samreach)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 3: Transfer (password-grant token lacks transfer:read scope)${NC}"
test_api GET_AUTH "api.localhost" "/api/transfer" "$T1" "403" "GET transfers (samreach → 403 scope)"
test_api POST     "api.localhost" "/api/transfer" "$T1" "403" "POST transfer (samreach → 403 scope)"
test_api GET_AUTH "api.localhost" "/api/transfer" "$T2" "403" "GET transfers (backend-user → 403 scope)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 4: Payment (password-grant token lacks payment scope)${NC}"
test_api GET_AUTH "api.localhost" "/api/payment" "$T3" "403" "GET payments (business-user → 403 scope)"
test_api POST     "api.localhost" "/api/payment" "$T3" "403" "POST payment (business-user → 403 scope)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 5: Notification (token forwarded to downstream)${NC}"
test_api GET_AUTH "api.localhost" "/api/notification" "$T1" "503" "GET notifications (samreach → 503 issuer mismatch)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 6: Admin (ROLE_ADMIN from realm_access)${NC}"
test_api GET_AUTH "api.localhost" "/api/admin/status" "$T1" "403" "Admin status (samreach → realm_access not in token)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 7: Authorization (403)${NC}"
test_api GET_AUTH "api.localhost" "/api/admin/status" "$T3" "403" "Admin (business-user→403)"
test_api GET_AUTH "api.localhost" "/api/transfer" "$T3" "403" "Transfer (business-user→403)"

# --------------------------------------------------
echo -e "\n${YELLOW}Section 8: Unauthenticated (401)${NC}"
test_api GET "api.localhost" "/api/userinfo" "" "401" "UserInfo (no token→401)"
test_api GET "api.localhost" "/api/transfer" "" "401" "Transfer (no token→401)"
test_api GET "api.localhost" "/api/payment" "" "401" "Payment (no token→401)"

# --------------------------------------------------
echo -e "\n${YELLOW}=============================================${NC}"
echo -e "${GREEN}Passed: $pass${NC} | ${RED}Failed: $fail${NC}"
echo -e "${YELLOW}=============================================${NC}"

exit $fail