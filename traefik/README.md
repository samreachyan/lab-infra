# 🔐 Traefik TLS Certificate Guide

This directory contains Traefik's dynamic configuration and TLS certificates for local development.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `dynamic.yml` | File-based routing configuration (routers, services, TLS stores) |
| `generate-key.sh` | Generate self-signed wildcard certificates |
| `certs/localhost.crt` | Wildcard TLS certificate (`*.localhost`) |
| `certs/localhost.key` | Private key (keep secret!) |

---

## 🚀 Generate TLS Certificates

```bash
# From the project root:
chmod +x traefik/generate-key.sh
./traefik/generate-key.sh
```

### Certificate Details

| Field | Value |
|-------|-------|
| **Common Name (CN)** | `*.localhost` |
| **Subject Alternative Names** | `localhost`, `*.localhost`, `keycloak.localhost`, `portal.localhost`, `api.localhost`, `grafana.localhost`, `prometheus.localhost`, `uptime-kuma.localhost`, `traefik.localhost` |
| **Key Size** | 4096-bit RSA |
| **Validity** | 365 days |
| **Algorithm** | SHA-256 |

---

## 🛠️ How Traefik Uses the Certificates

In `docker-compose.yml`, the certificates are mounted as read-only:

```yaml
traefik:
  volumes:
    - ./traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
    - ./traefik/certs:/etc/traefik/certs:ro
```

In `dynamic.yml`, Traefik references them:

```yaml
tls:
  certificates:
    - certFile: /etc/traefik/certs/localhost.crt
      keyFile: /etc/traefik/certs/localhost.key
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/localhost.crt
        keyFile: /etc/traefik/certs/localhost.key
```

---

## 🔑 Using Certificates with Keycloak

### Option 1: Import into Java Truststore (for internal TLS)

If Keycloak needs to trust the self-signed certificate (e.g., for backchannel communication):

```bash
# Copy the certificate into Keycloak container
docker cp traefik/certs/localhost.crt keycloak:/tmp/

# Import into Java truststore
docker exec -it keycloak keytool -import -trustcacerts \
  -alias sakcode-localhost \
  -file /tmp/localhost.crt \
  -keystore /opt/java/openjdk/lib/security/cacerts \
  -storepass changeit \
  -noprompt
```

### Option 2: Enable HTTPS on Keycloak

To enable HTTPS on Keycloak itself (not proxied via Traefik):

```bash
# Add to docker-compose.yml keycloak command:
--https-certificate-file=/opt/keycloak/conf/cert.pem
--https-certificate-key-file=/opt/keycloak/conf/key.pem

# And mount the certs:
volumes:
  - ./traefik/certs/localhost.crt:/opt/keycloak/conf/cert.pem:ro
  - ./traefik/certs/localhost.key:/opt/keycloak/conf/key.pem:ro
```

### Option 3: Generate Browser-Trusted Certificates (macOS)

For local development with browser trust (no SSL warnings):

```bash
# Install mkcert
brew install mkcert
mkcert -install

# Generate trusted certificates
cd traefik/certs
mkcert -cert-file localhost.crt -key-file localhost.key \
  localhost \
  '*.localhost' \
  keycloak.localhost \
  portal.localhost \
  api.localhost \
  grafana.localhost \
  prometheus.localhost
```

---

## 🏭 Production TLS

For production deployments, replace self-signed certificates with:

| Provider | Method | Automation |
|----------|--------|------------|
| **Let's Encrypt** | ACME via Traefik or certbot | ✅ Auto-renew |
| **step-ca** | Internal CA with ACME | ✅ Auto-renew |
| **HashiCorp Vault** | PKI secrets engine | ✅ Auto-renew |
| **Commercial CA** | Manual certificate purchase | ❌ Manual |

### Traefik ACME Example (Let's Encrypt)

```yaml
# Add to traefik command in docker-compose.yml:
--certificatesresolvers.letsencrypt.acme.email=admin@sakcode.com
--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/acme.json
--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web

# Add to router labels:
traefik.http.routers.xxx.tls.certresolver=letsencrypt
```

---

## ✅ Verify Certificates

```bash
# Check certificate content
openssl x509 -in traefik/certs/localhost.crt -text -noout

# Verify certificate matches private key
openssl x509 -noout -modulus -in traefik/certs/localhost.crt | openssl md5
openssl rsa -noout -modulus -in traefik/certs/localhost.key | openssl md5
# (Both should output the same hash)

# Test TLS connection
openssl s_client -connect localhost:443 -servername keycloak.localhost </dev/null 2>/dev/null | openssl x509 -noout -subject -dates