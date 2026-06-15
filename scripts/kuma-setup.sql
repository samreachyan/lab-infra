-- ============================================
-- Uptime Kuma Production Configuration
-- Inserts monitors for all platform services
-- ============================================

-- Get admin user_id
WITH admin_user AS (SELECT id FROM user WHERE username = 'admin' LIMIT 1)

-- Core Infrastructure: PostgreSQL (TCP port check)
INSERT INTO monitor (name, active, user_id, interval, url, type, hostname, port, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'PostgreSQL TCP', 1, id, 60, NULL, 'port', 'postgres', 5432, 3, 30, '["200-299"]', 'GET', 1, 2000, 'PostgreSQL database connectivity'
FROM admin_user;

-- Identity: Keycloak Health
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Keycloak Health', 1, id, 30, 'http://keycloak:8080/health/ready', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Keycloak identity provider health'
FROM admin_user;

-- Identity: Keycloak Realm
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Keycloak Realm', 1, id, 60, 'http://keycloak:8080/realms/sakcode-prod', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Keycloak realm accessibility'
FROM admin_user;

-- Proxy: Traefik Dashboard
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Traefik Dashboard', 1, id, 30, 'http://traefik:8080/dashboard/', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Traefik reverse proxy dashboard'
FROM admin_user;

-- Proxy: Traefik HTTP (TCP)
INSERT INTO monitor (name, active, user_id, interval, url, type, hostname, port, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Traefik HTTP', 1, id, 30, NULL, 'port', 'traefik', 80, 3, 10, '["200-299"]', 'GET', 1, 2000, 'Traefik HTTP listener'
FROM admin_user;

-- API Layer: Gateway
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'API Gateway', 1, id, 30, 'http://gateway:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Spring Cloud Gateway health'
FROM admin_user;

-- Backend: Transfer Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Transfer Service', 1, id, 60, 'http://transfer-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Transfer microservice health'
FROM admin_user;

-- Backend: Payment Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Payment Service', 1, id, 60, 'http://payment-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Payment microservice health'
FROM admin_user;

-- Backend: Notification Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Notification Service', 1, id, 60, 'http://notification-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Notification microservice health'
FROM admin_user;

-- Frontend: Portal UI
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Portal UI', 1, id, 60, 'http://portal-ui:80', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Portal frontend availability'
FROM admin_user;

-- Observability: Grafana
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Grafana', 1, id, 60, 'http://grafana:3000/api/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Grafana dashboards health'
FROM admin_user;

-- Observability: Prometheus
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Prometheus', 1, id, 60, 'http://prometheus:9090/-/healthy', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Prometheus metrics health'
FROM admin_user;

-- Observability: OAuth2-Proxy
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'OAuth2-Proxy', 1, id, 60, 'http://oauth2-proxy:4180/ping', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'OAuth2 proxy health'
FROM admin_user;

-- Self: Uptime Kuma
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Uptime Kuma', 1, id, 60, 'http://uptime-kuma:3001', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Uptime Kuma self-monitoring'
FROM admin_user;

-- ============================================
-- Public Status Page
-- ============================================
INSERT INTO status_page (slug, title, description, icon, theme, published, search_engine_index, show_tags, show_powered_by, footer_text, custom_css, auto_refresh_interval)
VALUES (
    'status',
    'Platform Services Status',
    'Real-time health status of all platform infrastructure and application services',
    '/icon.svg',
    'light',
    1,
    1,
    0,
    0,
    'Powered by Platform DevOps Team',
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; } .item { padding: 12px 0; }',
    30
);

-- Link all monitors to status page
INSERT INTO maintenance_status_page (maintenance_id, status_page_id, is_maintenance_page)
SELECT NULL, (SELECT id FROM status_page WHERE slug = 'status' LIMIT 1), 0
WHERE NOT EXISTS (SELECT 1 FROM maintenance_status_page WHERE status_page_id = (SELECT id FROM status_page WHERE slug = 'status' LIMIT 1));

-- ============================================
-- Done
-- ============================================