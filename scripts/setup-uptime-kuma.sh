#!/usr/bin/env bash
# ============================================
# Uptime Kuma Production Setup Script
# Monitors all services, configures alerts & status page
# ============================================

set -euo pipefail

KUMA_URL="http://uptime-kuma:3001"
KUMA_USER="${KUMA_USER:-admin}"
KUMA_PASS="${KUMA_PASS:-admin12345}"
STATUS_PAGE_SLUG="${STATUS_PAGE_SLUG:-status}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $*"; }
err() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2; }

# Wait for Kuma to be ready
wait_for_kuma() {
    log "Waiting for Uptime Kuma to be ready..."
    for i in {1..60}; do
        if curl -sf -o /dev/null "${KUMA_URL}/" 2>/dev/null; then
            log "Uptime Kuma is ready!"
            return 0
        fi
        sleep 2
    done
    err "Uptime Kuma failed to start within 120s"
    return 1
}

# Get JWT token
get_token() {
    curl -sf -X POST "${KUMA_URL}/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${KUMA_USER}\",\"password\":\"${KUMA_PASS}\"}" \
        -c /tmp/kuma_cookie.jar | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true
}

# Create admin account if needed
setup_account() {
    log "Setting up admin account..."
    
    # Try login first
    TOKEN=$(get_token)
    if [[ -n "$TOKEN" ]]; then
        log "Admin account already exists, logged in."
        export TOKEN
        return 0
    fi

    # Need to create account via setup
    curl -sf -X POST "${KUMA_URL}/setup" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${KUMA_USER}\",\"password\":\"${KUMA_PASS}\",\"passwordRepeat\":\"${KUMA_PASS}\"}"
    
    TOKEN=$(get_token)
    if [[ -z "$TOKEN" ]]; then
        err "Failed to create/login admin account"
        return 1
    fi
    export TOKEN
    log "Admin account created successfully"
}

# API helper
kuma_api() {
    local method=$1
    local endpoint=$2
    local data="${3:-}"
    
    if [[ -n "$data" ]]; then
        curl -sf -X "$method" "${KUMA_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${TOKEN}" \
            -b /tmp/kuma_cookie.jar \
            -d "$data"
    else
        curl -sf -X "$method" "${KUMA_URL}${endpoint}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -b /tmp/kuma_cookie.jar
    fi
}

# Create HTTP monitor
create_http_monitor() {
    local name=$1
    local url=$2
    local interval=${3:-60}
    local retry=${4:-3}
    local timeout=${5:-30}
    local accepted_statuscodes=${6:-["200-299"]}
    
    log "Creating monitor: ${name} -> ${url}"
    
    kuma_api POST "/api/monitor" "{
        \"type\": \"http\",
        \"name\": \"${name}\",
        \"url\": \"${url}\",
        \"interval\": ${interval},
        \"retry\": ${retry},
        \"timeout\": ${timeout},
        \"accepted_statuscodes\": ${accepted_statuscodes},
        \"expiryNotification\": true,
        \"ignoreTls\": false,
        \"maxredirects\": 10,
        \"method\": \"GET\",
        \"hostname\": null,
        \"port\": null,
        \"maxretries\": 3,
        \"notificationIDList\": {},
        \" upsideDown\": false,
        \"packetSize\": 56,
        \"resendInterval\": 0
    }" || warn "Failed to create monitor: ${name}"
}

# Create TCP monitor
create_tcp_monitor() {
    local name=$1
    local hostname=$2
    local port=$3
    local interval=${4:-60}
    
    log "Creating TCP monitor: ${name} -> ${hostname}:${port}"
    
    kuma_api POST "/api/monitor" "{
        \"type\": \"port\",
        \"name\": \"${name}\",
        \"hostname\": \"${hostname}\",
        \"port\": ${port},
        \"interval\": ${interval},
        \"retry\": 3,
        \"timeout\": 30,
        \"expiryNotification\": true,
        \"notificationIDList\": {},
        \"maxretries\": 3,
        \"resendInterval\": 0
    }" || warn "Failed to create monitor: ${name}"
}

# Create Docker container monitor (via TCP/HTTP fallback)
create_docker_monitor() {
    local name=$1
    local container=$2
    # We'll use the Docker socket approach or HTTP health endpoint
    # For now, create a simple HTTP monitor to the container's health endpoint if available
    log "Note: Docker container '${container}' monitoring via available health endpoints"
}

setup_monitors() {
    log "Configuring service monitors..."
    
    # Core Infrastructure
    create_http_monitor "PostgreSQL" "http://postgres:5432" 60 3 10 '["200-299","400-499"]'
    create_tcp_monitor "PostgreSQL TCP" "postgres" 5432 60
    
    # Identity Provider
    create_http_monitor "Keycloak Health" "http://keycloak:8080/health" 30 3 10 '["200-299"]'
    create_http_monitor "Keycloak Realm" "http://keycloak:8080/realms/sakcode-prod" 60 3 15 '["200-299"]'
    
    # Reverse Proxy
    create_http_monitor "Traefik Dashboard" "http://traefik:8080/dashboard/" 30 3 10 '["200-299"]'
    create_tcp_monitor "Traefik HTTP" "traefik" 80 30
    
    # API Layer
    create_http_monitor "API Gateway" "http://gateway:8080/actuator/health" 30 3 15 '["200-299"]'
    
    # Backend Services
    create_http_monitor "Transfer Service" "http://transfer-service:8080/actuator/health" 60 3 15 '["200-299"]'
    create_http_monitor "Payment Service" "http://payment-service:8080/actuator/health" 60 3 15 '["200-299"]'
    create_http_monitor "Notification Service" "http://notification-service:8080/actuator/health" 60 3 15 '["200-299"]'
    
    # Portal
    create_http_monitor "Portal UI" "http://portal-ui:80" 60 3 10 '["200-299"]'
    
    # Observability Stack
    create_http_monitor "Grafana" "http://grafana:3000/api/health" 60 3 15 '["200-299"]'
    create_http_monitor "Prometheus" "http://prometheus:9090/-/healthy" 60 3 15 '["200-299"]'
    create_http_monitor "OAuth2-Proxy" "http://oauth2-proxy:4180/ping" 60 3 10 '["200-299"]'
    
    # Uptime Kuma self-monitor
    create_http_monitor "Uptime Kuma" "http://uptime-kuma:3001" 60 3 10 '["200-299"]'
}

setup_notifications() {
    log "Configuring notification channels..."
    
    # Create a Discord/Slack/Teams placeholder - using webhook
    # In production, replace with actual webhook URL
    kuma_api POST "/api/notification" "{
        \"name\": \"Platform Alerts\",
        \"type\": \"webhook\",
        \"isDefault\": true,
        \"webhookURL\": \"${ALERT_WEBHOOK_URL:-}\",
        \"applyExisting\": true
    }" || warn "Failed to create webhook notification (may need ALERT_WEBHOOK_URL)"
    
    # Add email notification if SMTP is configured
    if [[ -n "${SMTP_HOST:-}" ]]; then
        kuma_api POST "/api/notification" "{
            \"name\": \"Email Alerts\",
            \"type\": \"smtp\",
            \"isDefault\": false,
            \"smtpHost\": \"${SMTP_HOST}\",
            \"smtpPort\": ${SMTP_PORT:-587},
            \"smtpSecure\": ${SMTP_SECURE:-false},
            \"smtpIgnoreTLSError\": false,
            \"username\": \"${SMTP_USER:-}\",
            \"password\": \"${SMTP_PASS:-}\",
            \"toEmail\": \"${ALERT_EMAIL:-ops@example.com}\",
            \"fromEmail\": \"${FROM_EMAIL:-uptime@example.com}\"
        }" || warn "Failed to create email notification"
    fi
}

setup_status_page() {
    log "Creating public status page..."
    
    # Create status page
    kuma_api POST "/api/status-page" "{
        \"slug\": \"${STATUS_PAGE_SLUG}\",
        \"title\": \"Platform Services Status\",
        \"description\": \"Real-time status of all platform services\",
        \"icon\": \"/icon.svg\",
        \"theme\": \"light\",
        \"published\": true,
        \"showTags\": false,
        \"customCSS\": \"body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }\",
        \"showPoweredBy\": false
    }" || warn "Failed to create status page (may already exist)"
}

verify_setup() {
    log "Verifying configuration..."
    
    local monitor_count
    monitor_count=$(kuma_api GET "/api/monitor" | grep -o '"monitorID"' | wc -l | tr -d ' ')
    
    log "Total monitors configured: ${monitor_count}"
    
    # List all monitors
    kuma_api GET "/api/monitor" | grep -o '"name":"[^"]*"' | sed 's/"name":"/  - /;s/"//'
}

main() {
    log "=========================================="
    log "Uptime Kuma Production Setup"
    log "=========================================="
    
    wait_for_kuma
    setup_account
    setup_monitors
    setup_notifications
    setup_status_page
    verify_setup
    
    log "=========================================="
    log "Setup complete!"
    log "Dashboard: http://uptime-kuma.localhost"
    log "Status Page: http://uptime-kuma.localhost/status/${STATUS_PAGE_SLUG}"
    log "=========================================="
}

main "$@"