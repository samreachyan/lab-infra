package com.sakcode.transfer.controller;

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
@RequestMapping("/api/transfers")
public class TransferController {

    private static final Logger log = LoggerFactory.getLogger(TransferController.class);
    private final List<Map<String, Object>> transfers = new ArrayList<>();

    @GetMapping
    @PreAuthorize("hasAuthority('SCOPE_transfer:read')")
    public ResponseEntity<Map<String, Object>> getTransfers(@AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        log.info("User {} accessing transfers (scope: {})", username, jwt.getClaimAsString("scope"));
        return ResponseEntity.ok(Map.of(
            "transfers", transfers,
            "count", transfers.size(),
            "accessedBy", username,
            "timestamp", Instant.now().toString()
        ));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('SCOPE_transfer:write')")
    public ResponseEntity<Map<String, Object>> createTransfer(
            @RequestBody Map<String, Object> transfer,
            @AuthenticationPrincipal Jwt jwt) {
        String username = jwt.getClaimAsString("preferred_username");
        String transferId = UUID.randomUUID().toString();
        Map<String, Object> newTransfer = new HashMap<>(transfer);
        newTransfer.put("id", transferId);
        newTransfer.put("createdBy", username);
        newTransfer.put("createdAt", Instant.now().toString());
        newTransfer.put("status", "PENDING");
        transfers.add(newTransfer);

        log.info("Transfer {} created by user {}", transferId, username);
        return ResponseEntity.ok(Map.of(
            "message", "Transfer created successfully",
            "transferId", transferId,
            "transfer", newTransfer
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "sakcode-transfer-service",
            "version", "1.0.0"
        ));
    }
}