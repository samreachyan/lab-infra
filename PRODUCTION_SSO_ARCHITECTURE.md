Below is a production-grade structure for the Markdown document. Because the full implementation (Traefik, Keycloak, PostgreSQL, Nginx, Portal UI, API Gateway, Transfer Service, Payment Service, Notification Service, Grafana, Prometheus, OAuth2-Proxy, Docker Compose, realm export JSON, Spring Security configs, JWT validation, role mappings, group mappings, TLS, observability, backup, disaster recovery, CI/CD, and troubleshooting) would be extremely large, I recommend building it as a multi-part architecture guide.

Use the following as your master document (`PRODUCTION_SSO_ARCHITECTURE.md`).

---

# Production SSO Architecture with Keycloak, Traefik, Spring Boot Microservices, Grafana and Prometheus

## Version

```text
Version: 1.0
Environment: Local Docker Compose
Identity Provider: Keycloak
Reverse Proxy: Traefik
Frontend: Nginx + SPA
Backend: Spring Boot
Monitoring: Grafana + Prometheus
Authentication: OpenID Connect (OIDC)
Authorization: JWT + Scopes + Roles
Architecture Style: Zero Trust
```

---

# Table of Contents

1. Executive Summary
2. Business Requirements
3. Functional Requirements
4. Non-Functional Requirements
5. Architecture Principles
6. System Context
7. High-Level Architecture
8. Trust Model
9. Authentication Architecture
10. Authorization Architecture
11. User Journey
12. Keycloak Architecture
13. Traefik Architecture
14. Portal Architecture
15. API Gateway Architecture
16. Microservice Security
17. Grafana SSO
18. Prometheus SSO
19. JWT Design
20. Role Design
21. Group Design
22. Docker Architecture
23. Network Design
24. Deployment Guide
25. Keycloak Configuration
26. Application Configuration
27. Security Best Practices
28. Monitoring
29. Auditing
30. Troubleshooting

---

# 1. Executive Summary

## Objective

Build a centralized enterprise identity platform using Keycloak that provides Single Sign-On for:

```text
Portal
API Gateway
Transfer Service
Payment Service
Notification Service
Grafana
Prometheus
```

---

## Expected Outcomes

Users authenticate once.

All applications trust Keycloak.

Applications never store passwords.

All services validate JWT independently.

---

# 2. Business Requirements

## BR-001

Provide centralized authentication.

---

## BR-002

Provide Single Sign-On.

---

## BR-003

Support role-based access control.

---

## BR-004

Support future mobile applications.

---

## BR-005

Support future Kubernetes migration.

---

## BR-006

Support audit and compliance requirements.

---

# 3. Functional Requirements

## Authentication

User shall:

```text
Login
Logout
Reset Password
Update Profile
Enable MFA
```

---

## Authorization

System shall support:

```text
Realm Roles
Client Roles
Groups
Scopes
JWT Claims
```

---

## Applications

```text
Portal
Grafana
Prometheus
```

must authenticate through Keycloak.

---

# 4. Non-Functional Requirements

## Security

```text
OIDC
OAuth2
JWT
TLS
MFA
```

---

## Scalability

Architecture must support:

```text
100+
Applications

1000+
Users
```

---

# 5. Architecture Principles

---

## Principle 1

Centralized Identity

```text
Only Keycloak manages identity.
```

---

## Principle 2

Zero Trust

```text
Never trust network location.
Always verify identity.
```

---

## Principle 3

Decentralized Authorization

Every service validates JWT.

---

## Principle 4

Least Privilege

Grant minimum permissions.

---

# 6. System Context

```text
Users
   │
   ▼

Browser / Mobile

   │
   ▼

Traefik

   │
   ▼

Keycloak

   │
   ▼

Applications
```

---

# 7. High-Level Architecture

```text
                         Browser

                            │

                            ▼

                        Traefik

                            │

     ┌──────────────────────┼──────────────────────┐

     ▼                      ▼                      ▼

 Keycloak               Portal UI             Grafana

     │                      │
     │                      ▼
     │                 API Gateway
     │                      │
     │                      ▼

     │      ┌───────────────┼───────────────┐

     ▼      ▼               ▼               ▼

Postgres Transfer      Payment      Notification

                            │

                            ▼

                       Prometheus
```

---

# 8. Trust Model

## Critical Question

Who trusts whom?

---

### Wrong

```text
Portal trusts Grafana
Grafana trusts Gateway
Gateway trusts Services
```

---

### Correct

```text
Portal trusts Keycloak

Grafana trusts Keycloak

Gateway trusts Keycloak

Transfer trusts Keycloak

Payment trusts Keycloak

Notification trusts Keycloak
```

---

# 9. Authentication Architecture

## Login Flow

```text
User

 │

 ▼

Portal

 │

 ▼

Redirect

 │

 ▼

Keycloak

 │

 ▼

Username + Password

 │

 ▼

JWT

 │

 ▼

Portal
```

---

## SSO Flow

```text
Portal
    │
    ▼

Keycloak Session

    │

Open Grafana

    │

    ▼

Keycloak

Existing Session

    │

    ▼

Grafana Login
```

---

# 10. Authorization Architecture

## JWT Example

```json
{
  "sub":"123",
  "preferred_username":"samreach",
  "realm_access":{
      "roles":["USER"]
  },
  "scope":"transfer:read payment:create"
}
```

---

## Service Authorization

Transfer Service:

```text
Requires:

transfer:read
```

Payment Service:

```text
Requires:

payment:create
```

---

# 11. User Journey

## First Login

```text
portal.localhost
```

↓

Redirect to Keycloak

↓

Authenticate

↓

Receive Tokens

↓

Access Portal

---

## Access Grafana

```text
grafana.localhost
```

↓

Existing Session

↓

Logged In

---

## Access Prometheus

```text
prometheus.localhost
```

↓

Existing Session

↓

Logged In

---

# 12. Keycloak Architecture

## Realm

```text
company
```

---

## Clients

```text
portal-ui
portal-api
grafana
prometheus-proxy
```

---

## Groups

```text
/admin
/devops
/backend
/business
```

---

## Realm Roles

```text
ADMIN
USER
DEVOPS
BACKEND
```

---

# 13. Traefik Architecture

## Responsibilities

```text
Routing
TLS
Load Balancing
Forward Authentication
```

---

## Domains

```text
keycloak.localhost
portal.localhost
api.localhost
grafana.localhost
prometheus.localhost
```

---

# 14. Portal Architecture

```text
React / Angular

        │

        ▼

Nginx

        │

        ▼

OIDC Login

        │

        ▼

Keycloak
```

---

# 15. API Gateway Architecture

## Responsibilities

```text
JWT Validation
Rate Limiting
Request Routing
Audit Logging
Tracing
```

---

## Not Responsible For

```text
Business Authorization
```

---

# 16. Microservice Security

## Every Service Must Validate JWT

```text
Gateway

Validate

Transfer

Validate

Payment

Validate

Notification

Validate
```

---

## Why?

Zero Trust.

---

# 17. Grafana SSO

## Client

```text
grafana
```

---

## Authentication

```text
OIDC
```

---

## Login Flow

```text
Grafana

↓

Keycloak

↓

JWT

↓

Grafana
```

---

# 18. Prometheus SSO

Prometheus has limited authentication.

Use:

```text
oauth2-proxy
```

Architecture:

```text
Browser

↓

Traefik

↓

oauth2-proxy

↓

Keycloak

↓

Prometheus
```

---

# 19. JWT Design

## Claims

```json
{
  "sub":"123",
  "preferred_username":"samreach",
  "email":"user@company.com",
  "scope":"transfer:read",
  "roles":["USER"]
}
```

---

# 20. Role Design

## Realm Roles

```text
ADMIN
USER
DEVOPS
BACKEND
```

---

## Client Roles

```text
grafana_admin

prometheus_admin

portal_admin
```

---

# 21. Group Design

Recommended:

```text
Groups

/devops
/backend
/admin
```

Assign roles to groups.

Assign users to groups.

Never assign permissions directly to users.

---

# 22. Docker Architecture

## Containers

```text
traefik
postgres
keycloak

portal-ui

gateway

transfer-service
payment-service
notification-service

grafana
prometheus
oauth2-proxy
```

---

# 23. Network Design

Single bridge network:

```yaml
networks:
  platform:
```

All containers join.

---

# 24. Deployment Guide

## Phase 1

PostgreSQL

---

## Phase 2

Keycloak

---

## Phase 3

Traefik

---

## Phase 4

Portal

---

## Phase 5

Gateway

---

## Phase 6

Services

---

## Phase 7

Grafana

---

## Phase 8

Prometheus

---

# 25. Keycloak Configuration

## Create Realm

```text
sakcode-prod
```

---

## Create User

```text
samreach
```

---

## Create Groups

```text
admin
devops
backend
```

---

## Create Clients

```text
portal-ui
portal-api
grafana
prometheus-proxy
```

---

# 26. Application Configuration

## Spring Boot

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri:
            http://keycloak:8080/realms/company
```

---

# 27. Security Best Practices

## Use MFA

Enable for all privileged users.

---

## Use Short-Lived Tokens

```text
Access Token: 5-15 min
```

---

## Rotate Secrets

Regularly.

---

## Enable HTTPS

Always.

---

# 28. Monitoring

Monitor:

```text
Keycloak
Gateway
Services
PostgreSQL
Traefik
```

Metrics:

```text
CPU
Memory
Latency
Authentication Failures
Token Errors
```

---

# 29. Auditing

Log:

```text
User ID
Client ID
IP Address
Request ID
Scope
Role
```

---

# 30. Troubleshooting

## Invalid Token

Check:

```text
Issuer
Audience
Expiration
Signature
```

---

## Login Loop

Check:

```text
Redirect URI
Web Origin
Cookie Domain
```

---

## 403 Forbidden

Check:

```text
Scopes
Roles
Group Mapping
```

---

# Final Rule

Whenever debugging SSO, ask:

```text
Who issued this identity?

Why should this service trust it?

How was that trust verified?
```

If you can answer those three questions for every request in the system, you fully understand the architecture.
