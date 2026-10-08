-- ==============================================================================
-- FSE Capstone: Master Operational Database Initialization Script
-- Engine: Azure SQL Database (T-SQL)
-- Target Database: sqldb-master
-- Replaces legacy local Oracle XE 21c (XEPDB1)
-- ==============================================================================

-- Drop existing tables in reverse dependency order
IF OBJECT_ID('dbo.outbox_events', 'U') IS NOT NULL DROP TABLE dbo.outbox_events;
IF OBJECT_ID('dbo.notifications', 'U') IS NOT NULL DROP TABLE dbo.notifications;
IF OBJECT_ID('dbo.transactions', 'U') IS NOT NULL DROP TABLE dbo.transactions;
IF OBJECT_ID('dbo.balance_master', 'U') IS NOT NULL DROP TABLE dbo.balance_master;
IF OBJECT_ID('dbo.accounts', 'U') IS NOT NULL DROP TABLE dbo.accounts;
IF OBJECT_ID('dbo.users', 'U') IS NOT NULL DROP TABLE dbo.users;

-- ==============================================================================
-- 1. Table: users
-- ==============================================================================
CREATE TABLE dbo.users (
    user_id                 NVARCHAR(64) NOT NULL PRIMARY KEY,
    first_name              NVARCHAR(100) NOT NULL,
    middle_name             NVARCHAR(100) NULL,
    last_name               NVARCHAR(100) NOT NULL,
    email                   NVARCHAR(255) NOT NULL UNIQUE,
    phone_number            NVARCHAR(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           NVARCHAR(100) NOT NULL,
    role                    NVARCHAR(20) NOT NULL,
    password_hash           NVARCHAR(255) NOT NULL,
    pin_hash                NVARCHAR(255) NULL,
    max_concurrent_sessions SMALLINT DEFAULT 3 NOT NULL,
    failed_login_attempts   SMALLINT DEFAULT 0 NOT NULL,
    status                  NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at              DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at              DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT chk_usr_role CHECK (role IN ('CUSTOMER', 'TELLER', 'MANAGER', 'ADMIN')),
    CONSTRAINT chk_usr_status CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED'))
);

-- ==============================================================================
-- 2. Table: accounts
-- ==============================================================================
CREATE TABLE dbo.accounts (
    account_id     NVARCHAR(64) NOT NULL PRIMARY KEY,
    user_id        NVARCHAR(64) NOT NULL,
    account_number NVARCHAR(32) NOT NULL UNIQUE,
    account_type   NVARCHAR(20) NOT NULL,
    status         NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    credit_limit   DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at     DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at     DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS')),
    CONSTRAINT chk_acc_status CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL')),
    CONSTRAINT chk_acc_credit_limit CHECK (credit_limit >= 0)
);

-- ==============================================================================
-- 3. Table: balance_master
-- Strict numeric parameters: DECIMAL(18, 4) with mathematical sanity checks
-- Concurrency target for: SELECT ... WITH (UPDLOCK, ROWLOCK)
-- ==============================================================================
CREATE TABLE dbo.balance_master (
    account_id        NVARCHAR(64) NOT NULL PRIMARY KEY,
    balance_amount    DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    hold_amount       DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    available_balance DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_bm_account FOREIGN KEY (account_id) REFERENCES dbo.accounts(account_id),
    CONSTRAINT chk_bm_positive_balance CHECK (balance_amount >= 0),
    CONSTRAINT chk_bm_positive_hold CHECK (hold_amount >= 0),
    CONSTRAINT chk_bm_available_balance CHECK (balance_amount >= hold_amount)
);

-- ==============================================================================
-- 4. Table: transactions
-- Maker-checker flag indicates transfers > PHP 50,000.00 requiring 2FA OTP
-- ==============================================================================
CREATE TABLE dbo.transactions (
    transaction_id         NVARCHAR(64) NOT NULL PRIMARY KEY,
    source_account_id      NVARCHAR(64) NOT NULL,
    target_account_id      NVARCHAR(64) NOT NULL,
    amount                 DECIMAL(18, 4) NOT NULL,
    currency               NVARCHAR(3) DEFAULT 'PHP' NOT NULL,
    transaction_type       NVARCHAR(20) NOT NULL,
    status                 NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    requires_maker_checker BIT DEFAULT 0 NOT NULL,
    approved_by            NVARCHAR(64) NULL,
    memo                   NVARCHAR(255) NULL,
    created_at             DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at             DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_tx_source FOREIGN KEY (source_account_id) REFERENCES dbo.accounts(account_id),
    CONSTRAINT fk_tx_target FOREIGN KEY (target_account_id) REFERENCES dbo.accounts(account_id),
    CONSTRAINT chk_tx_amount CHECK (amount > 0)
);

-- ==============================================================================
-- 5. Table: outbox_events (Transactional Outbox Pattern for Azure Event Hubs)
-- ==============================================================================
CREATE TABLE dbo.outbox_events (
    event_id        NVARCHAR(64) NOT NULL PRIMARY KEY,
    aggregate_type  NVARCHAR(64) NOT NULL,
    aggregate_id    NVARCHAR(64) NOT NULL,
    event_type      NVARCHAR(64) NOT NULL,
    payload         NVARCHAR(MAX) NOT NULL,
    status          NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    retry_count     INT DEFAULT 0 NOT NULL,
    created_at      DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    processed_at    DATETIMEOFFSET NULL
);

-- ==============================================================================
-- 6. Table: notifications
-- ==============================================================================
CREATE TABLE dbo.notifications (
    notification_id   NVARCHAR(64) NOT NULL PRIMARY KEY,
    user_id           NVARCHAR(64) NOT NULL,
    recipient_address NVARCHAR(255) NOT NULL,
    notification_type NVARCHAR(30) NOT NULL,
    channel           NVARCHAR(20) DEFAULT 'EMAIL' NOT NULL,
    subject           NVARCHAR(255) NOT NULL,
    content_payload   NVARCHAR(MAX) NOT NULL,
    dispatch_status   NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    delivery_attempts INT DEFAULT 0 NOT NULL,
    created_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    dispatched_at     DATETIMEOFFSET NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
);

-- Performance Indexes
CREATE NONCLUSTERED INDEX idx_acc_user_id ON dbo.accounts(user_id);
CREATE NONCLUSTERED INDEX idx_tx_source ON dbo.transactions(source_account_id, created_at DESC);
CREATE NONCLUSTERED INDEX idx_tx_target ON dbo.transactions(target_account_id, created_at DESC);
CREATE NONCLUSTERED INDEX idx_outbox_status ON dbo.outbox_events(status, created_at) WHERE status = 'PENDING';

-- ==============================================================================
-- Seed Baseline Data for Testing & Demonstration
-- ==============================================================================
INSERT INTO dbo.users (
    user_id, first_name, middle_name, last_name, email, phone_number, dob,
    government_id, role, password_hash, pin_hash, max_concurrent_sessions, failed_login_attempts, status
) VALUES 
('usr-1001-cst-001', 'Juan', 'Santos', 'Dela Cruz', 'juan.dc@email.com', '+639171234567', '1990-05-15', 'PASSPORT-P9876543A', 'CUSTOMER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 3, 0, 'ACTIVE'),
('usr-1002-cst-002', 'Maria', 'Clara', 'Reyes', 'maria.reyes@eastwestbanker.com', '+639189876543', '1992-08-20', 'UMID-0111-2233445-6', 'CUSTOMER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 3, 0, 'ACTIVE'),
('usr-1003-tel-001', 'Crisostomo', 'Alfonso', 'Ibarra', 'crisostomo.ibarra@eastwestbanker.com', '+639201112233', '1985-01-10', 'DRIVERS-LIC-N01-90-123456', 'TELLER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 5, 0, 'ACTIVE'),
('usr-1004-adm-001', 'Diana', 'Core', 'Administrator', 'diana.admin@bank.com', '+639000000000', '1980-01-01', 'COMPANY-ID-EMP-001', 'ADMIN', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', NULL, 10, 0, 'ACTIVE');

INSERT INTO dbo.accounts (account_id, user_id, account_number, account_type, status, credit_limit)
VALUES 
('1000-2000-3001', 'usr-1001-cst-001', '1000-2000-3001', 'SAVINGS', 'ACTIVE', 0.0000),
('1000-2000-3002', 'usr-1002-cst-002', '1000-2000-3002', 'SAVINGS', 'ACTIVE', 0.0000),
('1000-2000-3003', 'usr-1001-cst-001', '1000-2000-3003', 'CHECKING', 'ACTIVE', 0.0000),
('acc-2001-sav-001', 'usr-1001-cst-001', '100100001234', 'SAVINGS', 'ACTIVE', 0.0000),
('acc-2002-chk-001', 'usr-1001-cst-001', '100100005678', 'SAVINGS', 'ACTIVE', 0.0000),
('acc-2003-sav-002', 'usr-1002-cst-002', '100200009999', 'SAVINGS', 'ACTIVE', 0.0000);

INSERT INTO dbo.balance_master (account_id, balance_amount, hold_amount, available_balance)
VALUES 
('1000-2000-3001', 25000000.0000, 0.0000, 25000000.0000),
('1000-2000-3002', 5000000.0000, 0.0000, 5000000.0000),
('1000-2000-3003', 10000000.0000, 0.0000, 10000000.0000),
('acc-2001-sav-001', 25000000.0000, 5000000.0000, 20000000.0000),
('acc-2002-chk-001', 8500000.0000, 0.0000, 8500000.0000),
('acc-2003-sav-002', 12345678.1250, 0.0000, 12345678.1250);

