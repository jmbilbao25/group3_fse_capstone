package com.bank.ledger.notification;

import com.bank.ledger.notification.controller.NotificationController;
import com.bank.ledger.notification.controller.NotificationStreamController;
import com.bank.ledger.notification.entity.NotificationEntity;
import com.bank.ledger.notification.repository.NotificationRepository;
import com.bank.ledger.notification.service.EmailNotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class NotificationControllerTest {

    @Mock
    private EmailNotificationService emailService;

    @Mock
    private NotificationRepository notificationRepository;

    @Mock
    private NotificationStreamController streamController;

    @InjectMocks
    private NotificationController notificationController;

    private NotificationStreamController realStreamController;

    @BeforeEach
    void setUp() {
        realStreamController = new NotificationStreamController();
    }

    @Test
    @DisplayName("Should handle security alert, persist entity and broadcast via stream controller")
    void testHandleSecurityAlert() {
        Map<String, Object> request = Map.of(
                "user_id", "USR-100001",
                "title", "Security Alert: New Device Login",
                "message", "A new device (iPad) just logged into your account.",
                "device_name", "iPad Pro",
                "client_ip", "192.168.1.50",
                "target_device_id", "dev-primary-iphone"
        );

        ResponseEntity<Map<String, Object>> response = notificationController.handleSecurityAlert(request);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals("DISPATCHED", response.getBody().get("status"));
        assertEquals("SECURITY_ALERT", response.getBody().get("type"));
        assertEquals("USR-100001", response.getBody().get("user_id"));
        assertEquals("iPad Pro", response.getBody().get("device_name"));
        assertEquals("dev-primary-iphone", response.getBody().get("target_device_id"));

        verify(notificationRepository).save(any(NotificationEntity.class));
        verify(streamController).pushSecurityAlert(eq("USR-100001"), any());
    }

    @Test
    @DisplayName("Should establish SSE connection and push security alert to user emitter")
    void testStreamControllerSsePush() {
        SseEmitter emitter = realStreamController.streamNotifications("USR-100001");
        assertNotNull(emitter);

        assertDoesNotThrow(() -> {
            realStreamController.pushSecurityAlert("USR-100001", Map.of(
                    "title", "Security Alert: New Device Login",
                    "device_name", "iPad Pro"
            ));
        });
    }
}
