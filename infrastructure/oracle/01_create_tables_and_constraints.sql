-- ==============================================================================
-- CAPSTONE FSE: Core Retail Ledger & Balance Mutation Engine
-- Epic B: Database & Schema Design (Oracle XE 21c Master Database)
-- File: 01_create_tables_and_constraints.sql
-- Description: Definitive Oracle XE 21c Schema Definition matching the
--              official Group 3 Engineering Repository Source of Truth.
-- ==============================================================================

SET ECHO ON;
SET FEEDBACK ON;
SET SQLBLANKLINES ON;

-- ------------------------------------------------------------------------------
-- 1. USERS TABLE
-- Master profile for Customers, Tellers, and Admins.
-- ------------------------------------------------------------------------------
CREATE TABLE users (
    user_id                 VARCHAR2(64) PRIMARY KEY,
    first_name              VARCHAR2(100) NOT NULL,
    middle_name             VARCHAR2(100),
    last_name               VARCHAR2(100) NOT NULL,
    email                   VARCHAR2(255) NOT NULL UNIQUE,
    phone_number            VARCHAR2(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           VARCHAR2(100) NOT NULL,
    role                    VARCHAR2(20) NOT NULL CHECK (role IN ('CUSTOMER', 'TELLER', 'MANAGER', 'ADMIN')),
    password_hash           VARCHAR2(255) NOT NULL,
    pin_hash                VARCHAR2(255),
    max_concurrent_sessions NUMBER(3) DEFAULT 3 NOT NULL,
    failed_login_attempts   NUMBER(3) DEFAULT 0 NOT NULL,
    status                  VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED')),
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

COMMENT ON TABLE users IS 'Master table for all system users (Customers, Tellers, Admins)';
COMMENT ON COLUMN users.user_id IS 'Unique identifier (UUID or business key like U1001)';
COMMENT ON COLUMN users.government_id IS 'Valid government issued ID (Passport, UMID, Drivers License)';
COMMENT ON COLUMN users.failed_login_attempts IS 'Failed login counter. Account is locked when reaching 5';


-- ------------------------------------------------------------------------------
-- 2. ACCOUNTS TABLE
-- Customer bank accounts (Savings, Checking, Credit).
-- ------------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id     VARCHAR2(64) PRIMARY KEY,
    user_id        VARCHAR2(64) NOT NULL,
    account_number VARCHAR2(32) NOT NULL UNIQUE,
    account_type   VARCHAR2(20) NOT NULL CHECK (account_type IN ('SAVINGS', 'CREDIT')),
    status         VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL')),
    credit_limit   NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (credit_limit >= 0),
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

COMMENT ON TABLE accounts IS 'Stores individual customer bank account records';
COMMENT ON COLUMN accounts.account_number IS 'Official formatted bank account number';
COMMENT ON COLUMN accounts.credit_limit IS 'Approved credit limit for CREDIT accounts; 0 for standard deposit accounts';


-- ------------------------------------------------------------------------------
-- 3. BALANCE_MASTER TABLE (Pessimistic Locking Target)
-- Dedicated table for live balances locked via SELECT ... FOR UPDATE.
-- ------------------------------------------------------------------------------
CREATE TABLE balance_master (
    account_id        VARCHAR2(64) PRIMARY KEY,
    balance_amount    NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (balance_amount >= 0),
    hold_amount       NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (hold_amount >= 0),
    available_balance NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_bm_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_bm_solvency CHECK (balance_amount >= hold_amount)
);

COMMENT ON TABLE balance_master IS 'Master balance records optimized for SELECT FOR UPDATE pessimistic locking';
COMMENT ON COLUMN balance_master.balance_amount IS 'Total ledger balance with 4 decimal places precision (@Digits(14,4))';
COMMENT ON COLUMN balance_master.hold_amount IS 'Funds frozen for pending approvals (Maker-Checker threshold > 100,000)';
COMMENT ON COLUMN balance_master.available_balance IS 'Spendable balance: (balance_amount - hold_amount)';

-- Trigger to automatically calculate and maintain available_balance
CREATE OR REPLACE TRIGGER trg_calc_available_balance
BEFORE INSERT OR UPDATE ON balance_master
FOR EACH ROW
BEGIN
    :NEW.available_balance := :NEW.balance_amount - :NEW.hold_amount;
    :NEW.updated_at := CURRENT_TIMESTAMP;
END;
/


-- ------------------------------------------------------------------------------
-- 4. CREDIT_ASSESSMENTS TABLE
-- Collateral evaluations and credit appraisals conducted by Bank Tellers.
-- ------------------------------------------------------------------------------
CREATE TABLE credit_assessments (
    assessment_id              VARCHAR2(64) PRIMARY KEY,
    account_id                 VARCHAR2(64) NOT NULL,
    user_id                    VARCHAR2(64) NOT NULL,
    collateral_type            VARCHAR2(50) NOT NULL CHECK (collateral_type IN ('REAL_ESTATE', 'VEHICLE', 'TIME_DEPOSIT')),
    collateral_description     CLOB NOT NULL,
    collateral_market_value    NUMBER(18, 4) NOT NULL,
    collateral_appraised_value NUMBER(18, 4) NOT NULL,
    credit_score               NUMBER(4) NOT NULL CHECK (credit_score BETWEEN 300 AND 850),
    approved_credit_limit      NUMBER(18, 4) NOT NULL,
    risk_tier                  VARCHAR2(20) NOT NULL CHECK (risk_tier IN ('LOW_RISK', 'MEDIUM_RISK', 'HIGH_RISK')),
    assessed_by_teller_id      VARCHAR2(64) NOT NULL,
    status                     VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ca_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_ca_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_ca_teller FOREIGN KEY (assessed_by_teller_id) REFERENCES users(user_id)
);

COMMENT ON TABLE credit_assessments IS 'Credit assessment evaluations conducted by bank staff for credit products';
COMMENT ON COLUMN credit_assessments.risk_tier IS 'Assigned customer risk category (LOW_RISK, MEDIUM_RISK, HIGH_RISK)';


-- ------------------------------------------------------------------------------
-- 5. TRANSACTIONS TABLE
-- Operational transaction ledger for balance mutations.
-- Uses distributed idempotency key (transaction_id) to eliminate duplicate debits.
-- ------------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id         VARCHAR2(64) PRIMARY KEY,
    from_account_id        VARCHAR2(64) NOT NULL,
    to_account_id          VARCHAR2(64),
    type                   VARCHAR2(30) NOT NULL CHECK (type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'CREDIT_DRAW')),
    amount                 NUMBER(18, 4) NOT NULL CHECK (amount > 0),
    before_balance         NUMBER(18, 4) NOT NULL,
    after_balance          NUMBER(18, 4) NOT NULL,
    status                 VARCHAR2(30) NOT NULL CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED')),
    requires_maker_checker NUMBER(1) DEFAULT 0 NOT NULL CHECK (requires_maker_checker IN (0, 1)),
    approved_by_user_id    VARCHAR2(64),
    created_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_tx_from_acc FOREIGN KEY (from_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_to_acc FOREIGN KEY (to_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_approver FOREIGN KEY (approved_by_user_id) REFERENCES users(user_id)
);

COMMENT ON TABLE transactions IS 'Operational transaction log for all deposits, withdrawals, and fund transfers';
COMMENT ON COLUMN transactions.transaction_id IS 'Idempotency key generated by client/gateway to eliminate duplicate executions';
COMMENT ON COLUMN transactions.requires_maker_checker IS 'Flag (1=True, 0=False) indicating transaction requires checker sign-off';


-- ------------------------------------------------------------------------------
-- 6. OUTBOX_EVENTS TABLE
-- Transactional Outbox Pattern for reliable Kafka Event Bus delivery.
-- ------------------------------------------------------------------------------
CREATE TABLE outbox_events (
    event_id       VARCHAR2(64) PRIMARY KEY,
    aggregate_type VARCHAR2(50) NOT NULL CHECK (aggregate_type IN ('TRANSACTION', 'MAKER_CHECKER', 'BALANCE_MUTATION')),
    aggregate_id   VARCHAR2(64) NOT NULL,
    event_type     VARCHAR2(50) NOT NULL CHECK (event_type IN ('MAKER_PENDING', 'CHECKER_APPROVED', 'MUTATION_COMMITTED')),
    kafka_topic    VARCHAR2(100) NOT NULL,
    payload        CLOB NOT NULL,
    status         VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    retry_count    NUMBER(4) DEFAULT 0 NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at   TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_oe_aggregate FOREIGN KEY (aggregate_id) REFERENCES transactions(transaction_id)
);

COMMENT ON TABLE outbox_events IS 'Transactional outbox table for reliable asynchronous event delivery to Kafka';
COMMENT ON COLUMN outbox_events.payload IS 'Complete JSON serialized payload dispatched to messaging brokers';


-- ------------------------------------------------------------------------------
-- 7. NOTIFICATIONS TABLE
-- Stores in-app alerts and notifications sent to users.
-- ------------------------------------------------------------------------------
CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    user_id         VARCHAR2(64) NOT NULL,
    type            VARCHAR2(50) NOT NULL CHECK (type IN ('TRANSACTION_ALERT', 'SECURITY_ALERT', 'MAKER_CHECKER_ALERT')),
    message         CLOB NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

COMMENT ON TABLE notifications IS 'User alerts for transaction confirmations and security notices';
