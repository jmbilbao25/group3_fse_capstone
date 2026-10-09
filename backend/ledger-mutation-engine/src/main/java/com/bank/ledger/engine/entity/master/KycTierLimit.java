package com.bank.ledger.engine.entity.master;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/** Transfer limits per KYC tier. Data, not code, so compliance can tune them. */
@Entity
@Table(name = "kyc_tier_limits")
@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class KycTierLimit {

    @Id
    @Column(name = "kyc_tier")
    private Integer kycTier;

    @Column(name = "tier_name", nullable = false, length = 30)
    private String tierName;

    @Column(name = "per_txn_limit", nullable = false, precision = 18, scale = 4)
    private BigDecimal perTxnLimit;

    @Column(name = "daily_limit", nullable = false, precision = 18, scale = 4)
    private BigDecimal dailyLimit;

    @Column(name = "monthly_limit", nullable = false, precision = 18, scale = 4)
    private BigDecimal monthlyLimit;

    @Column(name = "description", nullable = false, length = 255)
    private String description;
}
