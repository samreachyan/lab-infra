#!/bin/bash
# ============================================
# Generate TLS Certificates for Traefik + Keycloak
# ============================================
# This script generates self-signed wildcard certificates
# for local development with *.localhost domains.
#
# Output:
#   certs/localhost.crt  — Certificate (import into Traefik + Keycloak truststore)
#   certs/localhost.key  — Private key
#
# Usage:
#   chmod +x traefik/generate-key.sh
#   ./traefik/generate-key.sh
# ============================================

set -e

CERT_DIR="$(dirname "$0")/certs"
mkdir -p "$CERT_DIR"

DAYS=365
KEY_SIZE=4096
COUNTRY="KH"
STATE="Phnom Penh"
CITY="Phnom Penh"
ORG="SakCode"
OU="Infrastructure"
CN="*.localhost"
SAN="DNS:*.localhost,DNS:localhost,DNS:keycloak.localhost,DNS:portal.localhost,DNS:api.localhost,DNS:grafana.localhost,DNS:prometheus.localhost,DNS:uptime-kuma.localhost,DNS:traefik.localhost"

echo "============================================="
echo "  SakCode TLS Certificate Generator"
echo "============================================="
echo ""
echo "  Subject:  CN=${CN}, O=${ORG}"
echo "  Validity: ${DAYS} days"
echo "  Key Size: ${KEY_SIZE} bits"
echo "  SANs:     ${SAN}"
echo ""

# --------------------------------------------------
# Step 1: Generate private key
# --------------------------------------------------
echo "🔑 Generating private key..."
openssl genrsa -out "${CERT_DIR}/localhost.key" ${KEY_SIZE} 2>/dev/null
echo "   ✅ ${CERT_DIR}/localhost.key"

# --------------------------------------------------
# Step 2: Generate self-signed certificate
# --------------------------------------------------
echo "📜 Generating self-signed certificate..."
openssl req -x509 -new -nodes \
    -key "${CERT_DIR}/localhost.key" \
    -sha256 -days ${DAYS} \
    -out "${CERT_DIR}/localhost.crt" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${CN}" \
    -addext "subjectAltName=${SAN}" \
    2>/dev/null
echo "   ✅ ${CERT_DIR}/localhost.crt"

# --------------------------------------------------
# Step 3: Verify certificate
# --------------------------------------------------
echo ""
echo "🔍 Certificate details:"
openssl x509 -in "${CERT_DIR}/localhost.crt" -text -noout 2>/dev/null | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:" | sed 's/^/   /'

echo ""
echo "============================================="
echo "  ✅ TLS certificates generated successfully!"
echo "============================================="
echo ""
echo "Files created:"
echo "  ${CERT_DIR}/localhost.crt"
echo "  ${CERT_DIR}/localhost.key"
echo ""
echo "These certificates are used by:"
echo "  - Traefik  → /etc/traefik/certs/ (mounted in docker-compose.yml)"
echo "  - Keycloak → Import localhost.crt into Java truststore for TLS"
echo ""
echo "For production use, replace with certificates from:"
echo "  - Let's Encrypt (via certbot or Traefik ACME)"
echo "  - Internal CA (e.g., step-ca, HashiCorp Vault)"
echo "  - Commercial CA (DigiCert, GlobalSign, etc.)"