package com.fse.banking.account.model;

import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "users")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserEntity {

    @Id
    @Column(name = "user_id", length = 64, nullable = false)
    private String userId;

    @Column(name = "first_name", length = 100, nullable = false)
    private String firstName;

    @Column(name = "middle_name", length = 100)
    private String middleName;

    @Column(name = "last_name", length = 100, nullable = false)
    private String lastName;

    @Column(name = "email", length = 255, nullable = false, unique = true)
    private String email;

    @Column(name = "phone_number", length = 30, nullable = false, unique = true)
    private String phoneNumber;

    @Column(name = "dob", nullable = false)
    private LocalDate dob;

    @Column(name = "government_id", length = 100, nullable = false)
    private String governmentId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", length = 20, nullable = false)
    private UserRole role;

    @Column(name = "password_hash", length = 255, nullable = false)
    private String passwordHash;

    @Column(name = "pin_hash", length = 255)
    private String pinHash;

    @Column(name = "max_concurrent_sessions", nullable = false)
    @Builder.Default
    private Integer maxConcurrentSessions = 3;

    @Column(name = "failed_login_attempts", nullable = false)
    @Builder.Default
    private Integer failedLoginAttempts = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    @Builder.Default
    private UserStatus status = UserStatus.ACTIVE;

    @Column(name = "last_known_latitude")
    @Builder.Default
    private Double lastKnownLatitude = 14.5995;

    @Column(name = "last_known_longitude")
    @Builder.Default
    private Double lastKnownLongitude = 120.9842;

    @Column(name = "last_known_location_name", length = 100)
    @Builder.Default
    private String lastKnownLocationName = "Manila, Philippines";

    @Column(name = "last_known_ip", length = 45)
    @Builder.Default
    private String lastKnownIp = "112.198.45.10";

    @Column(name = "last_geo_updated_at")
    private Instant lastGeoUpdatedAt;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    public void prePersist() {
        Instant now = Instant.now();
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        this.updatedAt = now;
        if (this.maxConcurrentSessions == null) {
            this.maxConcurrentSessions = 3;
        }
        if (this.failedLoginAttempts == null) {
            this.failedLoginAttempts = 0;
        }
        if (this.status == null) {
            this.status = UserStatus.ACTIVE;
        }
    }

    @PreUpdate
    public void preUpdate() {
        this.updatedAt = Instant.now();
    }
}
