package com.sakcode.payment.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/payments")
public class PaymentController {

    private static final Logger log = LoggerFactory.getLogger(PaymentController.class);
    private final List<Map<String, Object>> payments = new ArrayList<>();

    @GetMapping
    @PreAuthorize("hasAuthority('SCOPE_payment:read')")
    public ResponseEntity<Map<String, Object>> getPayments(@AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        log.info("User {} accessing payments", username);
        return ResponseEntity.ok(Map.of(
            "payments", payments,
            "count", payments.size(),
            "accessedBy", username,
            "timestamp", Instant.now().toString()
        ));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('SCOPE_payment:create')")
    public ResponseEntity<Map<String, Object>> createPayment(
            @RequestBody Map<String, Object> payment,
            @AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        String paymentId = UUID.randomUUID().toString();
        Map<String, Object> newPayment = new HashMap<>(payment);
        newPayment.put("id", paymentId);
        newPayment.put("createdBy", username);
        newPayment.put("createdAt", Instant.now().toString());
        newPayment.put("status", "PROCESSING");
        payments.add(newPayment);

        log.info("Payment {} initiated by user {}", paymentId, username);
        return ResponseEntity.ok(Map.of(
            "message", "Payment initiated successfully",
            "paymentId", paymentId,
            "payment", newPayment
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "sakcode-payment-service",
            "version", "1.0.0"
        ));
    }
}