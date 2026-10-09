package com.bank.ledger.engine.exception;

import lombok.Getter;

import java.math.BigDecimal;

/** The transfer would break the customer's KYC tier limit. Mapped to HTTP 422. */
@Getter
public class TransferLimitExceededException extends RuntimeException {

    private final int kycTier;
    private final String tierName;
    private final String limitType;
    private final BigDecimal limit;
    private final BigDecimal remaining;

    public TransferLimitExceededException(int kycTier, String tierName, String limitType, BigDecimal limit, BigDecimal remaining, String message) {
        super(message);
        this.kycTier = kycTier;
        this.tierName = tierName;
        this.limitType = limitType;
        this.limit = limit;
        this.remaining = remaining;
    }
}
