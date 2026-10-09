package com.fse.banking.account.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;

@Entity
@Table(name = "balance_master")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BalanceMasterEntity {

    @Id
    @Column(name = "balance_id", length = 64, nullable = false)
    private String balanceId;

    @Column(name = "account_id", length = 64, nullable = false, unique = true)
    private String accountId;

    @Column(name = "balance_amount", precision = 18, scale = 4, nullable = false)
    @Builder.Default
    private BigDecimal balanceAmount = BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);

    @Column(name = "hold_amount", precision = 18, scale = 4, nullable = false)
    @Builder.Default
    private BigDecimal holdAmount = BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);

    @Column(name = "available_balance", precision = 18, scale = 4, nullable = false)
    @Builder.Default
    private BigDecimal availableBalance = BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    public void prePersist() {
        if (this.balanceId == null || this.balanceId.isBlank()) {
            this.balanceId = "BM-" + (this.accountId != null ? this.accountId : java.util.UUID.randomUUID().toString());
        }
        Instant now = Instant.now();
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        this.updatedAt = now;
        normalizeBalances();
    }

    @PreUpdate
    public void preUpdate() {
        this.updatedAt = Instant.now();
        normalizeBalances();
    }

    public void normalizeBalances() {
        if (this.balanceAmount == null) {
            this.balanceAmount = BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);
        } else {
            this.balanceAmount = this.balanceAmount.setScale(4, RoundingMode.HALF_UP);
        }
        if (this.holdAmount == null) {
            this.holdAmount = BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);
        } else {
            this.holdAmount = this.holdAmount.setScale(4, RoundingMode.HALF_UP);
        }
        this.availableBalance = this.balanceAmount.subtract(this.holdAmount).setScale(4, RoundingMode.HALF_UP);
    }
}
