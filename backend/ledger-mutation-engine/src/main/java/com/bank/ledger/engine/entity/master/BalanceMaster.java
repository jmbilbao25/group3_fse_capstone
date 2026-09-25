package com.bank.ledger.engine.entity.master;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "balance_master")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BalanceMaster {

    @Id
    @Column(name = "account_id", length = 64)
    private String accountId;

    @Column(name = "balance_amount", nullable = false, precision = 18, scale = 4)
    private BigDecimal balanceAmount;

    @Column(name = "hold_amount", nullable = false, precision = 18, scale = 4)
    private BigDecimal holdAmount;

    @Column(name = "available_balance", nullable = false, precision = 18, scale = 4)
    private BigDecimal availableBalance;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}