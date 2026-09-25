package com.bank.ledger.notification.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Slf4j
@RestController
@RequestMapping("/api/v1/notifications")
@CrossOrigin(origins = "*")
public class NotificationStreamController {

    // Store active SSE emitters per customer or global broadcast
    private final CopyOnWriteArrayList<SseEmitter> activeEmitters = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<String, CopyOnWriteArrayList<SseEmitter>> userEmitters = new ConcurrentHashMap<>();

    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamNotifications(@RequestParam(value = "userId", required = false) String userId) {
        SseEmitter emitter = new SseEmitter(180_000L); // 3 minutes timeout
        activeEmitters.add(emitter);

        if (userId != null && !userId.isBlank()) {
            userEmitters.computeIfAbsent(userId, k -> new CopyOnWriteArrayList<>()).add(emitter);
        }

        emitter.onCompletion(() -> removeEmitter(emitter, userId));
        emitter.onTimeout(() -> removeEmitter(emitter, userId));
        emitter.onError((e) -> removeEmitter(emitter, userId));

        try {
            emitter.send(SseEmitter.event()
                    .name("CONNECTED")
                    .data(Map.of("message", "Connected to Real-Time Notification Stream", "status", "ONLINE")));
        } catch (IOException e) {
            removeEmitter(emitter, userId);
        }

        log.info("Client connected to SSE stream. Total active: {}", activeEmitters.size());
        return emitter;
    }

    public void pushToast(String userId, Object payload) {
        // Send to specific user if registered
        if (userId != null && userEmitters.containsKey(userId)) {
            for (SseEmitter emitter : userEmitters.get(userId)) {
                try {
                    emitter.send(SseEmitter.event().name("TRANSACTION_ALERT").data(payload));
                } catch (Exception e) {
                    removeEmitter(emitter, userId);
                }
            }
        }

        // Broadcast to general stream listeners
        for (SseEmitter emitter : activeEmitters) {
            try {
                emitter.send(SseEmitter.event().name("TRANSACTION_TOAST").data(payload));
            } catch (Exception e) {
                removeEmitter(emitter, userId);
            }
        }
    }

    private void removeEmitter(SseEmitter emitter, String userId) {
        activeEmitters.remove(emitter);
        if (userId != null && userEmitters.containsKey(userId)) {
            userEmitters.get(userId).remove(emitter);
        }
    }
}
