package com.bank.ledger.contracts.exception;

/**
 * Custom checked exception thrown when a dual-write failure or persistence error occurs.
 * Mandated by Capstone Specification (Section 1.C):
 * "If the PostgreSQL server drops offline mid-transaction, the entire block must trigger
 * a clean rollback on Oracle XE, throwing a custom checked LedgerPersistenceException
 * to prevent un-audited state changes."
 */
public class LedgerPersistenceException extends Exception {

    public LedgerPersistenceException(String message) {
        super(message);
    }

    public LedgerPersistenceException(String message, Throwable cause) {
        super(message, cause);
    }
}
