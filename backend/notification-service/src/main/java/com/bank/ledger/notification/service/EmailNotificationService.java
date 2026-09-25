package com.bank.ledger.notification.service;

import com.bank.ledger.contracts.dto.TransactionNotificationEvent;

import java.util.Map;

public interface EmailNotificationService {

    /**
     * Dispatches HTML transaction receipt email to customer inbox.
     * Uses Redis deduplication to prevent duplicate sends on Kafka rebalance.
     */
    boolean sendTransactionReceipt(TransactionNotificationEvent event);

    /**
     * Dispatches Tier 2 Dual Control Maker-Checker compliance alert email to Bank Operations Manager (Level 1).
     */
    boolean sendMakerCheckerAlert(TransactionNotificationEvent event);

    /**
     * Dispatches Tier 3 AMLA Covered / High-Value alert email (CTR required) to Dual Managers (Level 1 & Level 2).
     */
    boolean sendAmlaHighValueAlert(TransactionNotificationEvent event);

    /**
     * Returns the current status of the retry buffer spool.
     */
    Map<String, Object> getSpoolStatus();

    /**
     * Flushes buffered retry emails manually.
     */
    int flushRetrySpool();
}
