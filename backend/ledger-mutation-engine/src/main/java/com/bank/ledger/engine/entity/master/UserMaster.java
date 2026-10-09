package com.bank.ledger.engine.entity.master;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserMaster {

    @Id
    @Column(name = "user_id", length = 64, nullable = false)
    private String userId;

    @Column(name = "first_name", length = 100, nullable = false)
    private String firstName;

    @Column(name = "middle_name", length = 100)
    private String middleName;

    @Column(name = "last_name", length = 100, nullable = false)
    private String lastName;

    @Column(name = "email", length = 255, nullable = false)
    private String email;

    @Column(name = "phone_number", length = 30, nullable = false)
    private String phoneNumber;

    @Column(name = "role", length = 20, nullable = false)
    private String role;

    @Column(name = "status", length = 20, nullable = false)
    private String status;

    @Column(name = "last_known_latitude")
    private Double lastKnownLatitude;

    @Column(name = "last_known_longitude")
    private Double lastKnownLongitude;

    @Column(name = "last_known_location_name", length = 100)
    private String lastKnownLocationName;

    @Column(name = "last_known_ip", length = 45)
    private String lastKnownIp;

    @Column(name = "last_geo_updated_at")
    private Instant lastGeoUpdatedAt;

    @Column(name = "updated_at")
    private Instant updatedAt;
}
