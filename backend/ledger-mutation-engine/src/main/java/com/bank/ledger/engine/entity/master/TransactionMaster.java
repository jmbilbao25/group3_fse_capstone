package com.bank.ledger.engine.entity.master;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "transactions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransactionMaster {

    @Id
    @Column(name = "transaction_id", length = 64)
    private String transactionId;

    @Column(name = "from_account_id", nullable = false, length = 64)
    private String fromAccountId;

    @Column(name = "to_account_id", length = 64)
    private String toAccountId;

    @Column(name = "type", nullable = false, length = 30)
    private String type; // TRANSFER

    @Column(name = "amount", nullable = false, precision = 18, scale = 4)
    private BigDecimal amount;

    @Column(name = "before_balance", nullable = false, precision = 18, scale = 4)
    private BigDecimal beforeBalance;

    @Column(name = "after_balance", nullable = false, precision = 18, scale = 4)
    private BigDecimal afterBalance;

    @Column(name = "status", nullable = false, length = 30)
    private String status; // PENDING_APPROVAL, COMMITTED, FAILED

    @Column(name = "requires_2fa_otp", nullable = false)
    private Integer requires2FaOtp; // 0 or 1

    @Column(name = "approved_by_user_id", length = 64)
    private String approvedByUserId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // Backward-compatibility accessors
    public Integer getRequiresMakerChecker() {
        return requires2FaOtp != null ? requires2FaOtp : 0;
    }

    public void setRequiresMakerChecker(Integer val) {
        this.requires2FaOtp = val;
    }

    public static class TransactionMasterBuilder {
        public TransactionMasterBuilder requiresMakerChecker(Integer val) {
            this.requires2FaOtp = val;
            return this;
        }
    }
}