-- ==============================================================================
-- FSE Capstone: Compliance Audit Vault Database Initialization Script
-- Engine: Azure Database for PostgreSQL Flexible Server
-- Target Database: banking_audit
-- Preserves write-once append-only compliance with native trigger protection
-- ==============================================================================

-- ==============================================================================
-- TABLE: ledger_mutation_audit
-- Immutable Audit Trail Store
-- ==============================================================================
CREATE TABLE IF NOT EXISTS ledger_mutation_audit (
    audit_id            BIGSERIAL PRIMARY KEY,
    transaction_id      VARCHAR(64) NOT NULL UNIQUE,
    account_id          VARCHAR(36) NOT NULL,
    mutation_type       VARCHAR(16) NOT NULL,
    mutation_amount     NUMERIC(18, 4) NOT NULL,
    before_balance      NUMERIC(18, 4) NOT NULL,
    after_balance       NUMERIC(18, 4) NOT NULL,
    initiator_user_id   VARCHAR(36) NOT NULL,
    approved_by_user_id VARCHAR(36),
    status              VARCHAR(20) NOT NULL DEFAULT 'COMMITTED',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ledger_mutation_audit_mutation_amount_check CHECK (mutation_amount > 0),
    CONSTRAINT ledger_mutation_audit_after_balance_check CHECK (after_balance >= 0),
    CONSTRAINT ledger_mutation_audit_mutation_type_check CHECK (
        mutation_type IN ('TRANSFER', 'DEBIT', 'CREDIT', 'HOLD', 'RELEASE', 'REVERSAL')
    ),
    CONSTRAINT ledger_mutation_audit_status_check CHECK (
        status IN ('COMMITTED', 'FAILED', 'ROLLED_BACK')
    )
);

-- Indexes for Auditor Queries
CREATE INDEX IF NOT EXISTS idx_audit_tx_id
    ON ledger_mutation_audit(transaction_id);

CREATE INDEX IF NOT EXISTS idx_audit_acc_time
    ON ledger_mutation_audit(account_id, created_at DESC);

-- ==============================================================================
-- IMMUTABILITY FUNCTION & TRIGGER
-- Blocks all SQL UPDATE and DELETE commands at the database engine level
-- ==============================================================================
CREATE OR REPLACE FUNCTION enforce_audit_immutability()
RETURNS TRIGGER AS
$$
BEGIN
    RAISE EXCEPTION 'Compliance Violation: ledger_mutation_audit is strictly append-only. UPDATE and DELETE operations are blocked.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_immutable_audit ON ledger_mutation_audit;

CREATE TRIGGER trg_immutable_audit
    BEFORE UPDATE OR DELETE
ON ledger_mutation_audit
FOR EACH ROW
EXECUTE FUNCTION enforce_audit_immutability();
