package com.sakcode.notification.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);
    private final List<Map<String, Object>> notifications = new ArrayList<>();

    @GetMapping
    public ResponseEntity<Map<String, Object>> getNotifications(@AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        log.info("User {} accessing notifications", username);
        return ResponseEntity.ok(Map.of(
            "notifications", notifications,
            "count", notifications.size(),
            "accessedBy", username,
            "timestamp", Instant.now().toString()
        ));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> sendNotification(
            @RequestBody Map<String, Object> notification,
            @AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        String notifId = UUID.randomUUID().toString();
        Map<String, Object> newNotification = new HashMap<>(notification);
        newNotification.put("id", notifId);
        newNotification.put("sentBy", username);
        newNotification.put("sentAt", Instant.now().toString());
        newNotification.put("status", "SENT");
        notifications.add(newNotification);

        log.info("Notification {} sent by user {}", notifId, username);
        return ResponseEntity.ok(Map.of(
            "message", "Notification sent successfully",
            "notificationId", notifId,
            "notification", newNotification
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "sakcode-notification-service",
            "version", "1.0.0"
        ));
    }
}