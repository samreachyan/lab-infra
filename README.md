# 🏢 SakCode Production SSO Architecture

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.0-green)
![Architecture](https://img.shields.io/badge/architecture-Zero%20Trust-red)

> **Version**: 1.0 | **Environment**: Local Docker Compose | **Architecture**: Zero Trust | **License**: MIT

Production-grade Single Sign-On platform with **Keycloak**, **Traefik**, **Spring Boot** microservices, **Grafana**, **Prometheus**, and **Uptime Kuma**.

---

## 📐 Architecture Overview

```
                            Browser (localhost)

                                   │
                                   ▼
                               Traefik (:80)
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
   Keycloak (:8080)          Portal UI (:80)            Grafana (:3000)
        │                     (Nginx + SPA)              (OAuth2 SSO)
        │                          │
        │                          ▼
        │                     API Gateway (:8080)
        │                          │
        │              ┌───────────┼───────────┐
        │              ▼           ▼           ▼
        │         Transfer    Payment    Notification
        │         Service     Service    Service
        │
        ▼
  Prometheus (:9090)  ←──  Uptime Kuma (:3001)
```

### Trust Model (Zero Trust)
- **Every service validates JWT independently**
- **No implicit trust between services**
- Only **Keycloak** is the identity authority

---

## 🔌 Port Mapping

| Port | Service | Purpose |
|------|---------|---------|
| `80` | Traefik | Reverse proxy (all `*.localhost` traffic) |
| `443` | Traefik | HTTPS (self-signed TLS) |
| `8080` | Keycloak | Identity Provider (also exposed externally) |
| `8082` | Traefik Dashboard | `traefik.localhost:8082` |
| `3000` | Grafana | Internal (via Traefik: `grafana.localhost`) |
| `3001` | Uptime Kuma | Internal (via Traefik: `uptime-kuma.localhost`) |
| `9090` | Prometheus | Internal (via Traefik: `prometheus.localhost`) |
| `4180` | OAuth2-Proxy | Prometheus auth proxy (not used currently) |

---

## 🌐 Services & URLs

| Service | URL | Auth Method | Status |
|---------|-----|------------|--------|
| **Portal UI** | http://portal.localhost | Keycloak OIDC | ✅ Running |
| **Keycloak Admin** | http://keycloak.localhost | admin/admin123 | ✅ Running |
| **API Gateway** | http://api.localhost | JWT Bearer | ✅ Running |
| **Grafana** | http://grafana.localhost | Keycloak SSO | ✅ Running |
| **Prometheus** | http://prometheus.localhost | No auth | ✅ Running |
| **Uptime Kuma** | http://uptime-kuma.localhost | Setup on first visit | ✅ Running |
| **Traefik Dashboard** | http://traefik.localhost:8082 | — | ✅ Running |

---

## 👥 Keycloak Users & Roles

| Username | Email | Password | Realm Roles | Grafana Role |
|----------|-------|----------|-------------|--------------|
| `samreach` | samreach@sakcode.com | `password123` | ADMIN, USER, DEVOPS, BACKEND, grafana_admin, prometheus_admin | **Admin** |
| `devops-user` | devops@sakcode.com | `password123` | DEVOPS, USER, grafana_admin, prometheus_admin | **Admin** |
| `backend-user` | backend@sakcode.com | `password123` | BACKEND, USER | Viewer |
| `business-user` | business@sakcode.com | `password123` | USER | Viewer |

### Role Mapping
- `grafana_admin` realm role → Grafana **Admin**
- `DEVOPS` realm role → Grafana **Editor**
- Other users → Grafana **Viewer**

---

## 🚀 Quick Start

```bash
# 1. Start all services
docker compose up -d

# 2. Wait for Keycloak bootstrap (~60 seconds)
docker compose logs keycloak -f

# 3. Verify all 12 containers are running
docker compose ps

# 4. Access the portal
open http://portal.localhost
```

### Test Credentials
```
Portal Login:    http://portal.localhost
  Username:      samreach
  Password:      password123

Keycloak Admin:  http://keycloak.localhost
  Username:      admin
  Password:      admin123

Grafana Login:   http://grafana.localhost
  → Click "Sign in with Keycloak"
  Username:      devops-user
  Password:      password123
```

---

## 🧪 API Gateway Testing

```bash
# Run the integration test suite (14 assertions)
./scripts/test-api-gateway.sh
```

### Sample curl Commands

```bash
# 1. Get JWT token
TOKEN=$(curl -s -X POST \
  "http://keycloak.localhost/realms/sakcode-prod/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=portal-ui" \
  -d "username=samreach" \
  -d "password=password123" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

# 2. Call authenticated endpoint
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  http://api.localhost/api/userinfo

# 3. Health check (no auth)
curl http://api.localhost/api/health
```

### API Gateway Routes

| Method | Path | Authorization |
|--------|------|---------------|
| `GET` | `/api/health` | Public |
| `GET` | `/api/userinfo` | Authenticated |
| `GET` / `POST` | `/api/transfer` | `SCOPE_transfer:read` / `SCOPE_transfer:write` |
| `GET` / `POST` | `/api/payment` | `SCOPE_payment:read` / `SCOPE_payment:create` |
| `GET` | `/api/notification` | Authenticated |
| `GET` | `/api/admin/status` | `ROLE_ADMIN` |

---

## 📊 Monitoring

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | http://grafana.localhost | Dashboards & alerting (SSO via Keycloak) |
| **Prometheus** | http://prometheus.localhost | Metrics collection (8 scrape jobs) |
| **Uptime Kuma** | http://uptime-kuma.localhost | Service uptime monitoring |
| **Traefik Dashboard** | http://traefik.localhost:8082 | Reverse proxy routes & health |

### Prometheus Metrics Endpoints
- Traefik: `/metrics` on port 8080
- Spring Boot services: `/actuator/prometheus` on port 8080
- Grafana: `/metrics` on port 3000
- Keycloak: `/metrics` on port 8080

---

## 🐳 Docker Containers (12 Total)

```
postgres               PostgreSQL 15 (Keycloak DB)
keycloak               Keycloak 26.6 (Identity Provider)
traefik                Traefik v3.1 (Reverse Proxy)
portal-ui              Nginx + SPA (Portal UI)
gateway                Spring Boot 3.2 (API Gateway)
transfer-service       Spring Boot 3.2 (Transfer Microservice)
payment-service        Spring Boot 3.2 (Payment Microservice)
notification-service   Spring Boot 3.2 (Notification Microservice)
grafana                Grafana 12 (Monitoring Dashboards)
prometheus             Prometheus 3.11 (Metrics)
oauth2-proxy           OAuth2-Proxy 7.6 (SSO for Prometheus - unused)
uptime-kuma            Uptime Kuma 2.4 (Uptime Monitoring)
```

---

## 🔧 Development Commands

```bash
# View logs for a specific service
docker compose logs -f gateway

# Rebuild a Spring Boot service after code changes
docker compose build gateway && docker compose up -d --force-recreate gateway

# Full restart (preserves volumes)
docker compose down && docker compose up -d

# Full reset (removes ALL data)
docker compose down -v && docker compose up -d

# Access Keycloak Admin CLI
docker exec -it keycloak /opt/keycloak/bin/kcadm.sh
```

---

## 🔒 Security Features

- **Zero Trust**: Every service independently validates JWT
- **Centralized Identity**: Only Keycloak manages users/passwords
- **Decentralized Authorization**: Each service enforces its own scope/role requirements
- **Least Privilege**: Fine-grained scopes (`transfer:read`, `payment:create`)
- **Stateless Sessions**: All services use `SessionCreationPolicy.STATELESS`
- **TLS**: Self-signed certificates for local development (`traefik/certs/`)
- **Security Headers**: CSP, HSTS, X-Frame-Options, X-Content-Type-Options
- **Rate Limiting**: API Gateway enforces per-endpoint rate limits

---

## 📁 Project Structure

```
LabInfra/
├── docker-compose.yml              # 12-container orchestration
├── PRODUCTION_SSO_ARCHITECTURE.md  # Detailed architecture document
├── README.md                       # This file
├── traefik/
│   ├── dynamic.yml                 # File-based routing config
│   └── certs/                      # TLS certificates
├── keycloak/
│   └── realm-export.json           # Pre-configured realm (auto-imported)
├── portal-ui/
│   ├── nginx.conf                  # Nginx config with security headers
│   └── html/index.html             # Portal SPA (OIDC client)
├── gateway/                        # API Gateway (Spring Boot)
├── transfer-service/               # Transfer Microservice
├── payment-service/                # Payment Microservice
├── notification-service/           # Notification Microservice
├── grafana/
│   └── provisioning/               # Datasource & dashboard provisioning
├── prometheus/
│   └── prometheus.yml              # Scrape configuration
└── scripts/
    └── test-api-gateway.sh         # API integration test suite
```

---

## 🐛 Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `401 Unauthorized` | Token expired or issuer mismatch | Get new token; verify `KC_HOSTNAME_PORT` |
| `403 Forbidden` | Missing scope/role in token | Token from password grant only has `openid profile email` |
| Grafana "Login failed" | User sync error | `docker volume rm labinfra_grafana_data -f` |
| Keycloak won't start | Port conflict | Check port 8080 isn't in use |
| Portal shows login page | Token expired | Clear `sessionStorage` and re-login |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

© 2026 SakCode. All rights reserved.
