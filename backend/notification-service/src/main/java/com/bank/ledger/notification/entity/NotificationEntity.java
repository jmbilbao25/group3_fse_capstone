package com.bank.ledger.notification.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

@Entity
@Table(name = "notifications")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationEntity {

    @Id
    @Column(name = "notification_id", length = 64, nullable = false)
    private String notificationId;

    @Column(name = "user_id", length = 64, nullable = false)
    private String userId;

    @Column(name = "type", length = 50, nullable = false)
    private String type; // TRANSACTION_ALERT, SECURITY_ALERT, MAKER_CHECKER_ALERT

    @Lob
    @Column(name = "message", nullable = false)
    private String message;

    @Column(name = "sent_at", nullable = false)
    private Instant sentAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
