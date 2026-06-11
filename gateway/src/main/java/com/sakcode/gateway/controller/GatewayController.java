package com.sakcode.gateway.controller;

import io.github.resilience4j.ratelimiter.annotation.RateLimiter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class GatewayController {

    private static final Logger log = LoggerFactory.getLogger(GatewayController.class);
    private final RestTemplate restTemplate;

    @Value("${service.transfer.url:http://transfer-service:8080}")
    private String transferServiceUrl;

    @Value("${service.payment.url:http://payment-service:8080}")
    private String paymentServiceUrl;

    @Value("${service.notification.url:http://notification-service:8080}")
    private String notificationServiceUrl;

    public GatewayController() {
        this.restTemplate = new RestTemplate();
    }

    // ============================================
    // Health and Info
    // ============================================
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "sakcode-api-gateway",
            "version", "1.0.0"
        ));
    }

    @GetMapping("/userinfo")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, Object>> userInfo(@AuthenticationPrincipal Jwt jwt) {
        Map<String, Object> info = new java.util.HashMap<>();
        info.put("sub", jwt.getSubject());
        info.put("username", jwt.getClaimAsString("preferred_username"));
        info.put("email", jwt.getClaimAsString("email"));
        info.put("name", jwt.getClaimAsString("name"));
        info.put("scopes", jwt.getClaimAsString("scope"));
        info.put("issuedAt", jwt.getIssuedAt());
        info.put("expiresAt", jwt.getExpiresAt());
        return ResponseEntity.ok(info);
    }

    // ============================================
    // Transfer Service Routes
    // ============================================
    @GetMapping("/transfer")
    @PreAuthorize("hasAuthority('SCOPE_transfer:read')")
    @RateLimiter(name = "transferRateLimiter")
    public ResponseEntity<String> getTransfers(@AuthenticationPrincipal Jwt jwt) {
        String requestId = UUID.randomUUID().toString();
        log.info("[{}] GET /api/transfer - user: {}", requestId, jwt.getSubject());
        return proxyRequest(transferServiceUrl + "/api/transfers", HttpMethod.GET, null);
    }

    @PostMapping("/transfer")
    @PreAuthorize("hasAuthority('SCOPE_transfer:write')")
    @RateLimiter(name = "transferRateLimiter")
    public ResponseEntity<String> createTransfer(@RequestBody String body, @AuthenticationPrincipal Jwt jwt) {
        String requestId = UUID.randomUUID().toString();
        log.info("[{}] POST /api/transfer - user: {}", requestId, jwt.getSubject());
        return proxyRequest(transferServiceUrl + "/api/transfers", HttpMethod.POST, body);
    }

    // ============================================
    // Payment Service Routes
    // ============================================
    @GetMapping("/payment")
    @PreAuthorize("hasAuthority('SCOPE_payment:read')")
    @RateLimiter(name = "paymentRateLimiter")
    public ResponseEntity<String> getPayments(@AuthenticationPrincipal Jwt jwt) {
        String requestId = UUID.randomUUID().toString();
        log.info("[{}] GET /api/payment - user: {}", requestId, jwt.getSubject());
        return proxyRequest(paymentServiceUrl + "/api/payments", HttpMethod.GET, null);
    }

    @PostMapping("/payment")
    @PreAuthorize("hasAuthority('SCOPE_payment:create')")
    @RateLimiter(name = "paymentRateLimiter")
    public ResponseEntity<String> createPayment(@RequestBody String body, @AuthenticationPrincipal Jwt jwt) {
        String requestId = UUID.randomUUID().toString();
        log.info("[{}] POST /api/payment - user: {}", requestId, jwt.getSubject());
        return proxyRequest(paymentServiceUrl + "/api/payments", HttpMethod.POST, body);
    }

    // ============================================
    // Notification Service Routes
    // ============================================
    @GetMapping("/notification")
    @PreAuthorize("isAuthenticated()")
    @RateLimiter(name = "notificationRateLimiter")
    public ResponseEntity<String> getNotifications(@AuthenticationPrincipal Jwt jwt) {
        String requestId = UUID.randomUUID().toString();
        log.info("[{}] GET /api/notification - user: {}", requestId, jwt.getSubject());
        return proxyRequest(notificationServiceUrl + "/api/notifications", HttpMethod.GET, null, jwt.getTokenValue());
    }

    // ============================================
    // Admin routes
    // ============================================
    @GetMapping("/admin/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> adminStatus() {
        Map<String, Object> status = new java.util.HashMap<>();
        status.put("gateway", "UP");
        status.put("transferService", transferServiceUrl);
        status.put("paymentService", paymentServiceUrl);
        status.put("notificationService", notificationServiceUrl);
        return ResponseEntity.ok(status);
    }

    // ============================================
    // Proxy helper
    // ============================================
    private ResponseEntity<String> proxyRequest(String url, HttpMethod method, String body) {
        return proxyRequest(url, method, body, null);
    }

    private ResponseEntity<String> proxyRequest(String url, HttpMethod method, String body, String bearerToken) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            if (bearerToken != null && !bearerToken.isEmpty()) {
                headers.setBearerAuth(bearerToken);
            }
            HttpEntity<String> entity = new HttpEntity<>(body, headers);
            ResponseEntity<String> response = restTemplate.exchange(url, method, entity, String.class);
            return ResponseEntity.status(response.getStatusCode()).body(response.getBody());
        } catch (Exception e) {
            log.error("Failed to proxy request to {}: {}", url, e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body("{\"error\": \"Service unavailable\", \"message\": \"" + e.getMessage() + "\"}");
        }
    }
}