-- ============================================
-- Uptime Kuma Production Configuration
-- ============================================

-- Get admin user id
PRAGMA foreign_keys = OFF;

-- First create a simple variable approach
-- Since SQLite doesn't have variables, we do individual selects

-- Core Infrastructure: PostgreSQL TCP
INSERT INTO monitor (name, active, user_id, interval, url, type, hostname, port, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'PostgreSQL TCP', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, NULL, 'port', 'postgres', 5432, 3, 30, '["200-299"]', 'GET', 1, 2000, 'PostgreSQL database connectivity';

-- Identity: Keycloak Health
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Keycloak Health', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 30, 'http://keycloak:8080/health/ready', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Keycloak identity provider health';

-- Identity: Keycloak Realm
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Keycloak Realm', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://keycloak:8080/realms/sakcode-prod', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Keycloak realm accessibility';

-- Proxy: Traefik Dashboard
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Traefik Dashboard', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 30, 'http://traefik:8080/dashboard/', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Traefik reverse proxy dashboard';

-- Proxy: Traefik HTTP (TCP)
INSERT INTO monitor (name, active, user_id, interval, url, type, hostname, port, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Traefik HTTP', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 30, NULL, 'port', 'traefik', 80, 3, 10, '["200-299"]', 'GET', 1, 2000, 'Traefik HTTP listener';

-- API Layer: Gateway
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'API Gateway', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 30, 'http://gateway:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Spring Cloud Gateway health';

-- Backend: Transfer Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Transfer Service', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://transfer-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Transfer microservice health';

-- Backend: Payment Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Payment Service', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://payment-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Payment microservice health';

-- Backend: Notification Service
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Notification Service', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://notification-service:8080/actuator/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Notification microservice health';

-- Frontend: Portal UI
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Portal UI', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://portal-ui:80', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Portal frontend availability';

-- Observability: Grafana
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Grafana', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://grafana:3000/api/health', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Grafana dashboards health';

-- Observability: Prometheus
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Prometheus', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://prometheus:9090/-/healthy', 'http', 3, 15, '["200-299"]', 'GET', 1, 2000, 'Prometheus metrics health';

-- Observability: OAuth2-Proxy
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'OAuth2-Proxy', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://oauth2-proxy:4180/ping', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'OAuth2 proxy health';

-- Self: Uptime Kuma
INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries, timeout, accepted_statuscodes_json, method, expiry_notification, weight, description)
SELECT 'Uptime Kuma', 1, (SELECT id FROM user WHERE username = 'admin' LIMIT 1), 60, 'http://uptime-kuma:3001', 'http', 3, 10, '["200-299"]', 'GET', 1, 2000, 'Uptime Kuma self-monitoring';

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
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }',
    30
);

PRAGMA foreign_keys = ON;