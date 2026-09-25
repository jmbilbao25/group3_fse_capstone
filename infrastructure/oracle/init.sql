-- ==============================================================================
-- FSE Capstone: Master Operational Database Initialization Script
-- Engine: Oracle Database 21c / Free 23ai
-- Container: oracle-xe-master
-- Pluggable Database: XEPDB1
-- Application User: fse_user
-- ==============================================================================
-- Ensure table creation is clean and deterministic
WHENEVER SQLERROR CONTINUE;

-- Switch to pluggable database and application user schema if run by SYS
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = fse_user;

-- Drop existing tables in reverse dependency order
DROP TABLE outbox_events CASCADE CONSTRAINTS;
DROP TABLE notifications CASCADE CONSTRAINTS;
DROP TABLE auth_sessions CASCADE CONSTRAINTS;
DROP TABLE transactions CASCADE CONSTRAINTS;
DROP TABLE credit_assessments CASCADE CONSTRAINTS;
DROP TABLE balance_master CASCADE CONSTRAINTS;
DROP TABLE accounts CASCADE CONSTRAINTS;
DROP TABLE users CASCADE CONSTRAINTS;

-- Legacy cleanups if present
DROP TABLE customer_balance_master CASCADE CONSTRAINTS;
DROP TABLE bills_payment CASCADE CONSTRAINTS;
DROP TABLE transfers CASCADE CONSTRAINTS;
DROP TABLE user_roles CASCADE CONSTRAINTS;
DROP TABLE roles CASCADE CONSTRAINTS;

WHENEVER SQLERROR EXIT FAILURE;

-- ==============================================================================
-- 1. Table: users
-- ==============================================================================
CREATE TABLE users (
    user_id                 VARCHAR2(64) PRIMARY KEY,
    first_name              VARCHAR2(100) NOT NULL,
    middle_name             VARCHAR2(100),
    last_name               VARCHAR2(100) NOT NULL,
    email                   VARCHAR2(255) NOT NULL UNIQUE,
    phone_number            VARCHAR2(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           VARCHAR2(100) NOT NULL,
    role                    VARCHAR2(20) NOT NULL,
    password_hash           VARCHAR2(255) NOT NULL,
    pin_hash                VARCHAR2(255),
    max_concurrent_sessions NUMBER(3) DEFAULT 3 NOT NULL,
    failed_login_attempts   NUMBER(3) DEFAULT 0 NOT NULL,
    status                  VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_usr_role CHECK (role IN ('CUSTOMER', 'TELLER', 'MANAGER', 'ADMIN')),
    CONSTRAINT chk_usr_status CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED'))
);

-- ==============================================================================
-- 2. Table: accounts
-- ==============================================================================
CREATE TABLE accounts (
    account_id     VARCHAR2(64) PRIMARY KEY,
    user_id        VARCHAR2(64) NOT NULL,
    account_number VARCHAR2(32) NOT NULL UNIQUE,
    account_type   VARCHAR2(20) NOT NULL,
    status         VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    credit_limit   NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS', 'CREDIT')),
    CONSTRAINT chk_acc_status CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL')),
    CONSTRAINT chk_acc_credit_limit CHECK (credit_limit >= 0)
);

-- ==============================================================================
-- 3. Table: balance_master
-- Strict numeric parameters: NUMBER(18, 4) with mathematical sanity checks
-- ==============================================================================
CREATE TABLE balance_master (
    account_id        VARCHAR2(64) PRIMARY KEY,
    balance_amount    NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    hold_amount       NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    available_balance NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_bm_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_bm_positive_balance CHECK (balance_amount >= 0),
    CONSTRAINT chk_bm_positive_hold CHECK (hold_amount >= 0),
    CONSTRAINT chk_bm_available_balance CHECK (balance_amount >= hold_amount)
);

-- ==============================================================================
-- 4. Table: credit_assessments
-- ==============================================================================
CREATE TABLE credit_assessments (
    assessment_id              VARCHAR2(64) PRIMARY KEY,
    account_id                 VARCHAR2(64) NOT NULL,
    user_id                    VARCHAR2(64) NOT NULL,
    collateral_type            VARCHAR2(50) NOT NULL,
    collateral_description     CLOB NOT NULL,
    collateral_market_value    NUMBER(18, 4) NOT NULL,
    collateral_appraised_value NUMBER(18, 4) NOT NULL,
    credit_score               NUMBER(4) NOT NULL,
    approved_credit_limit      NUMBER(18, 4) NOT NULL,
    risk_tier                  VARCHAR2(20) NOT NULL,
    assessed_by_teller_id      VARCHAR2(64) NOT NULL,
    status                     VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    created_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ca_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_ca_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_ca_teller FOREIGN KEY (assessed_by_teller_id) REFERENCES users(user_id),
    CONSTRAINT chk_ca_collateral_type CHECK (collateral_type IN ('REAL_ESTATE', 'VEHICLE', 'TIME_DEPOSIT')),
    CONSTRAINT chk_ca_risk_tier CHECK (risk_tier IN ('LOW_RISK', 'MEDIUM_RISK', 'HIGH_RISK')),
    CONSTRAINT chk_ca_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_ca_score CHECK (credit_score BETWEEN 300 AND 850)
);

-- ==============================================================================
-- 5. Table: transactions
-- Note: requires_maker_checker stored as NUMBER(1) for cross-driver compatibility
-- ==============================================================================
CREATE TABLE transactions (
    transaction_id         VARCHAR2(64) PRIMARY KEY,
    from_account_id        VARCHAR2(64) NOT NULL,
    to_account_id          VARCHAR2(64),
    type                   VARCHAR2(30) NOT NULL,
    amount                 NUMBER(18, 4) NOT NULL,
    before_balance         NUMBER(18, 4) NOT NULL,
    after_balance          NUMBER(18, 4) NOT NULL,
    status                 VARCHAR2(30) NOT NULL,
    requires_maker_checker NUMBER(1) DEFAULT 0 NOT NULL,
    approved_by_user_id    VARCHAR2(64),
    created_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_tx_from_account FOREIGN KEY (from_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_to_account FOREIGN KEY (to_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_approved_by FOREIGN KEY (approved_by_user_id) REFERENCES users(user_id),
    CONSTRAINT chk_tx_type CHECK (type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'CREDIT_DRAW')),
    CONSTRAINT chk_tx_status CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED')),
    CONSTRAINT chk_tx_maker_checker CHECK (requires_maker_checker IN (0, 1)),
    CONSTRAINT chk_tx_amount CHECK (amount > 0)
);

-- ==============================================================================
-- 6. Table: outbox_events
-- ==============================================================================
CREATE TABLE outbox_events (
    event_id       VARCHAR2(64) PRIMARY KEY,
    aggregate_type VARCHAR2(50) NOT NULL,
    aggregate_id   VARCHAR2(64) NOT NULL,
    event_type     VARCHAR2(50) NOT NULL,
    kafka_topic    VARCHAR2(100) NOT NULL,
    payload        CLOB NOT NULL,
    status         VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    retry_count    NUMBER(4) DEFAULT 0 NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at   TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_oe_aggregate FOREIGN KEY (aggregate_id) REFERENCES transactions(transaction_id),
    CONSTRAINT chk_oe_aggregate_type CHECK (aggregate_type IN ('TRANSACTION', 'MAKER_CHECKER', 'BALANCE_MUTATION')),
    CONSTRAINT chk_oe_event_type CHECK (event_type IN ('MAKER_PENDING', 'CHECKER_APPROVED', 'MUTATION_COMMITTED')),
    CONSTRAINT chk_oe_status CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED'))
);

-- ==============================================================================
-- 7. Table: notifications
-- ==============================================================================
CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    user_id         VARCHAR2(64) NOT NULL,
    type            VARCHAR2(50) NOT NULL,
    message         CLOB NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT chk_notif_type CHECK (type IN ('TRANSACTION_ALERT', 'SECURITY_ALERT', 'MAKER_CHECKER_ALERT'))
);

-- Note: Authentication session tokens and revocations are persisted in Redis (redis-cache).

-- ==============================================================================
-- Performance Indexes
-- ==============================================================================
CREATE INDEX idx_acc_user ON accounts(user_id);
CREATE INDEX idx_tx_from_acc ON transactions(from_account_id, created_at DESC);
CREATE INDEX idx_tx_to_acc ON transactions(to_account_id, created_at DESC);
CREATE INDEX idx_tx_status ON transactions(status);
CREATE INDEX idx_outbox_status ON outbox_events(status, created_at);
CREATE INDEX idx_notif_user ON notifications(user_id, sent_at DESC);

-- ==============================================================================
-- Seed Population: Realistic Banking Dataset
-- ==============================================================================

-- 1. Users
INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1001-cst-001', 'Juan', 'Santos', 'Dela Cruz', 'juan.delacruz@eastwestbanker.com', '+639171234567',
    TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'PASSPORT-P9876543A', 'CUSTOMER',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 3, 0, 'ACTIVE'
);

INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1002-cst-002', 'Maria', 'Clara', 'Reyes', 'maria.reyes@eastwestbanker.com', '+639189876543',
    TO_DATE('1992-08-20', 'YYYY-MM-DD'), 'UMID-0111-2233445-6', 'CUSTOMER',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 3, 0, 'ACTIVE'
);

INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1003-tel-001', 'Crisostomo', 'Alfonso', 'Ibarra', 'crisostomo.ibarra@eastwestbanker.com', '+639201112233',
    TO_DATE('1985-01-10', 'YYYY-MM-DD'), 'DRIVERS-LIC-N01-90-123456', 'TELLER',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 5, 0, 'ACTIVE'
);

INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1005-boo-001', 'Beatriz', 'Santos', 'Ocampo', 'beatriz.ocampo@eastwestbanker.com', '+639204445566',
    TO_DATE('1984-07-19', 'YYYY-MM-DD'), 'PRC-9988-7711', 'MANAGER',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 5, 0, 'ACTIVE'
);

INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1006-mgr-002', 'Carlos', 'Eduardo', 'Mendoza', 'carlos.mendoza@eastwestbanker.com', '+639171122334',
    TO_DATE('1982-11-05', 'YYYY-MM-DD'), 'PRC-5544-3322', 'MANAGER',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 5, 0, 'ACTIVE'
);

INSERT INTO users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES (
    'usr-1004-adm-001', 'System', 'Core', 'Administrator', 'admin.portal@eastwestbanker.com', '+639000000000',
    TO_DATE('1980-01-01', 'YYYY-MM-DD'), 'COMPANY-ID-EMP-001', 'ADMIN',
    '$2a$10$7EqJtq98hPqEX7fNZaFWoOdi14kS13h2qBwYvUo2a7Fv6z9O1Zqwe', NULL, 10, 0, 'ACTIVE'
);

-- 2. Accounts
INSERT INTO accounts (account_id, user_id, account_number, account_type, status, credit_limit)
VALUES ('acc-2001-sav-001', 'usr-1001-cst-001', '100100001234', 'SAVINGS', 'ACTIVE', 0.0000);

INSERT INTO accounts (account_id, user_id, account_number, account_type, status, credit_limit)
VALUES ('acc-2002-chk-001', 'usr-1001-cst-001', '100100005678', 'SAVINGS', 'ACTIVE', 0.0000);

INSERT INTO accounts (account_id, user_id, account_number, account_type, status, credit_limit)
VALUES ('acc-2003-sav-002', 'usr-1002-cst-002', '100200009999', 'SAVINGS', 'ACTIVE', 0.0000);

INSERT INTO accounts (account_id, user_id, account_number, account_type, status, credit_limit)
VALUES ('acc-2004-crd-001', 'usr-1001-cst-001', '400100007777', 'CREDIT', 'ACTIVE', 500000.0000);

-- 3. Balance Master (Exact 4-decimal precision)
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance)
VALUES ('acc-2001-sav-001', 25000000.0000, 5000000.0000, 20000000.0000);

INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance)
VALUES ('acc-2002-chk-001', 8500000.0000, 0.0000, 8500000.0000);

INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance)
VALUES ('acc-2003-sav-002', 12345678.1250, 0.0000, 12345678.1250);

INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance)
VALUES ('acc-2004-crd-001', 500000.0000, 150000.0000, 350000.0000);

-- 4. Credit Assessments
INSERT INTO credit_assessments (
    assessment_id, account_id, user_id, collateral_type, collateral_description,
    collateral_market_value, collateral_appraised_value, credit_score,
    approved_credit_limit, risk_tier, assessed_by_teller_id, status
) VALUES (
    'asmt-3001-re-001', 'acc-2004-crd-001', 'usr-1001-cst-001', 'REAL_ESTATE',
    'Condominium Unit 12B, Fort Victoria, BGC Taguig City (TCT-987654)',
    12000000.0000, 9600000.0000, 785, 500000.0000, 'LOW_RISK', 'usr-1003-tel-001', 'APPROVED'
);

-- 5. Transactions
-- Tx 1: High-value transfer pending Maker-Checker review (> 5M PHP hold applied)
INSERT INTO transactions (
    transaction_id, from_account_id, to_account_id, type, amount,
    before_balance, after_balance, status, requires_maker_checker, approved_by_user_id
) VALUES (
    'tx-4001-hld-001', 'acc-2001-sav-001', 'acc-2003-sav-002', 'TRANSFER', 5000000.0000,
    25000000.0000, 20000000.0000, 'PENDING_APPROVAL', 1, NULL
);

-- Tx 2: Committed standard transfer
INSERT INTO transactions (
    transaction_id, from_account_id, to_account_id, type, amount,
    before_balance, after_balance, status, requires_maker_checker, approved_by_user_id
) VALUES (
    'tx-4002-cmt-002', 'acc-2002-chk-001', 'acc-2003-sav-002', 'TRANSFER', 150000.0000,
    8650000.0000, 8500000.0000, 'COMMITTED', 0, 'usr-1003-tel-001'
);

-- Tx 3: OTC Cash withdrawal
INSERT INTO transactions (
    transaction_id, from_account_id, to_account_id, type, amount,
    before_balance, after_balance, status, requires_maker_checker, approved_by_user_id
) VALUES (
    'tx-4003-otc-003', 'acc-2001-sav-001', NULL, 'WITHDRAWAL', 50000.0000,
    25050000.0000, 25000000.0000, 'COMMITTED', 0, 'usr-1003-tel-001'
);

-- 6. Outbox Events (Relay to Kafka)
INSERT INTO outbox_events (
    event_id, aggregate_type, aggregate_id, event_type, kafka_topic, payload, status, retry_count
) VALUES (
    'evt-5001-mk-001', 'MAKER_CHECKER', 'tx-4001-hld-001', 'MAKER_PENDING',
    'banking.makerchecker.pending',
    '{"transactionId":"tx-4001-hld-001","fromAccount":"acc-2001-sav-001","toAccount":"acc-2003-sav-002","amount":5000000.0000,"currency":"PHP","makerId":"usr-1001-cst-001"}',
    'PENDING', 0
);

INSERT INTO outbox_events (
    event_id, aggregate_type, aggregate_id, event_type, kafka_topic, payload, status, retry_count, published_at
) VALUES (
    'evt-5002-tx-002', 'TRANSACTION', 'tx-4002-cmt-002', 'MUTATION_COMMITTED',
    'banking.transfers.events',
    '{"transactionId":"tx-4002-cmt-002","fromAccount":"acc-2002-chk-001","toAccount":"acc-2003-sav-002","amount":150000.0000,"status":"COMMITTED"}',
    'PUBLISHED', 0, CURRENT_TIMESTAMP
);

-- 7. Notifications
INSERT INTO notifications (notification_id, user_id, type, message)
VALUES (
    'notif-6001-001', 'usr-1001-cst-001', 'TRANSACTION_ALERT',
    'Your transfer of PHP 5,000,000.0000 is currently under Maker-Checker verification.'
);

INSERT INTO notifications (notification_id, user_id, type, message)
VALUES (
    'notif-6002-002', 'usr-1003-tel-001', 'MAKER_CHECKER_ALERT',
    'High-value transfer tx-4001-hld-001 requires Supervisor authorization.'
);

COMMIT;
