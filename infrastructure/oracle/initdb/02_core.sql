-- =============================================================================
-- AURA_CORE: core banking system of record (Temenos T24 role).
-- Owned by ledger-mutation-engine. Holds money and the customer master (CIF);
-- knows nothing about passwords, devices or staff.
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE;
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = aura_core;

-- -----------------------------------------------------------------------------
-- KYC tier policy. Limits follow Philippine practice:
--   Tier 1 mirrors the BSP basic deposit account (simplified KYC, PHP 50k cap)
--   and e-wallet "basic" monthly limits; Tier 2 uses the InstaPay per-transfer
--   cap (PHP 50k) and the PHP 200k daily aggregate common at PH banks;
--   Tier 3 is enhanced due diligence (EDD) for high-value clients.
-- -----------------------------------------------------------------------------
CREATE TABLE kyc_tier_limits (
    kyc_tier        NUMBER(1) PRIMARY KEY,
    tier_name       VARCHAR2(30) NOT NULL,
    per_txn_limit   NUMBER(18, 4) NOT NULL,
    daily_limit     NUMBER(18, 4) NOT NULL,
    monthly_limit   NUMBER(18, 4) NOT NULL,
    description     VARCHAR2(255) NOT NULL,
    CONSTRAINT chk_tier_range CHECK (kyc_tier BETWEEN 0 AND 3),
    CONSTRAINT chk_tier_order CHECK (per_txn_limit <= daily_limit AND daily_limit <= monthly_limit)
);

-- Customer Information File. customer_id is the same id the channel uses for
-- the customer's login, so no mapping table is needed.
CREATE TABLE customers (
    customer_id     VARCHAR2(64) PRIMARY KEY,
    first_name      VARCHAR2(100) NOT NULL,
    middle_name     VARCHAR2(100),
    last_name       VARCHAR2(100) NOT NULL,
    dob             DATE NOT NULL,
    government_id   VARCHAR2(100) NOT NULL,
    kyc_tier        NUMBER(1) DEFAULT 0 NOT NULL,
    status          VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_cust_tier FOREIGN KEY (kyc_tier) REFERENCES kyc_tier_limits(kyc_tier),
    CONSTRAINT chk_cust_status CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED'))
);

CREATE TABLE accounts (
    account_id      VARCHAR2(64) PRIMARY KEY,
    customer_id     VARCHAR2(64) NOT NULL,
    account_number  VARCHAR2(32) NOT NULL UNIQUE,
    account_type    VARCHAR2(20) DEFAULT 'SAVINGS' NOT NULL,
    status          VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_acc_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS')),
    CONSTRAINT chk_acc_status CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL'))
);

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

-- approved_by_user_id / reversed_by_user_id hold AURA_ADMIN staff ids; they
-- are references by value, deliberately not foreign keys.
CREATE TABLE transactions (
    transaction_id       VARCHAR2(64) PRIMARY KEY,
    from_account_id      VARCHAR2(64) NOT NULL,
    to_account_id        VARCHAR2(64),
    type                 VARCHAR2(30) NOT NULL,
    amount               NUMBER(18, 4) NOT NULL,
    before_balance       NUMBER(18, 4) NOT NULL,
    after_balance        NUMBER(18, 4) NOT NULL,
    status               VARCHAR2(30) NOT NULL,
    requires_2fa_otp     NUMBER(1) DEFAULT 0 NOT NULL,
    approved_by_user_id  VARCHAR2(64),
    latitude             NUMBER(10, 6),
    longitude            NUMBER(10, 6),
    location_name        VARCHAR2(100),
    ip_address           VARCHAR2(45),
    risk_score           NUMBER(5, 2),
    risk_reason          VARCHAR2(255),
    reversed_by_user_id  VARCHAR2(64),
    reversal_reason      VARCHAR2(100),
    reversal_memo        VARCHAR2(255),
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_tx_from_account FOREIGN KEY (from_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_to_account FOREIGN KEY (to_account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_tx_type CHECK (type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'REVERSAL')),
    CONSTRAINT chk_tx_status CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED', 'REJECTED_FRAUD', 'REVERSED', 'CANCELLED', 'POSTED', 'INITIATED', 'PROCESSING')),
    CONSTRAINT chk_tx_2fa_otp CHECK (requires_2fa_otp IN (0, 1)),
    CONSTRAINT chk_tx_amount CHECK (amount > 0)
);

CREATE TABLE outbox_events (
    event_id        VARCHAR2(64) PRIMARY KEY,
    aggregate_type  VARCHAR2(50) NOT NULL,
    aggregate_id    VARCHAR2(64) NOT NULL,
    event_type      VARCHAR2(50) NOT NULL,
    kafka_topic     VARCHAR2(100) NOT NULL,
    payload         CLOB NOT NULL,
    status          VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    retry_count     NUMBER(4) DEFAULT 0 NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at    TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_outbox_status CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    CONSTRAINT chk_outbox_retry CHECK (retry_count >= 0)
);

CREATE INDEX idx_acc_customer ON accounts(customer_id);
CREATE INDEX idx_tx_from_acc ON transactions(from_account_id, created_at DESC);
CREATE INDEX idx_tx_to_acc ON transactions(to_account_id, created_at DESC);
CREATE INDEX idx_tx_status ON transactions(status);
CREATE INDEX idx_outbox_status ON outbox_events(status, created_at);

-- -----------------------------------------------------------------------------
-- Seed
-- -----------------------------------------------------------------------------
INSERT INTO kyc_tier_limits VALUES (0, 'Unverified', 0, 0, 0, 'Registered, identity not yet verified. Can receive, cannot send.');
INSERT INTO kyc_tier_limits VALUES (1, 'Basic', 10000, 20000, 50000, 'Simplified KYC: one valid ID and selfie reviewed by Aura.');
INSERT INTO kyc_tier_limits VALUES (2, 'Verified', 50000, 200000, 1000000, 'Full KYC: valid ID, selfie liveness, address and personal details verified.');
INSERT INTO kyc_tier_limits VALUES (3, 'Premier', 5000000, 10000000, 50000000, 'Enhanced due diligence: source of funds and income documents verified.');

-- Internal CIF that owns mirror accounts for other-bank beneficiaries and the
-- clearing suspense account. Never logs in; tier 0 so it can never send.
INSERT INTO customers (customer_id, first_name, last_name, dob, government_id, kyc_tier) VALUES ('cif-0000-ext-clr', 'Interbank', 'Clearing', DATE '2000-01-01', 'INTERNAL', 0);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-1001-cst-001', 'Juan', 'Santos', 'Dela Cruz', DATE '1990-05-15', 'PASSPORT-P9876543A', 3);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-1002-cst-002', 'Maria', 'Clara', 'Reyes', DATE '1992-08-20', 'UMID-0111-2233445-6', 2);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2003-cst-003', 'Jose', 'Protacio', 'Rizal', DATE '1987-06-19', 'PRC-1861-1234', 2);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2004-cst-004', 'Andres', 'Castro', 'Bonifacio', DATE '1989-11-30', 'PSA-1863-1130', 2);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2005-cst-005', 'Gabriela', 'Cario', 'Silang', DATE '1991-03-19', 'PSA-1988-1234', 1);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2006-cst-006', 'Emilio', 'Dizon', 'Jacinto', DATE '1993-12-15', 'PSA-1991-5678', 2);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2007-cst-007', 'Melchora', 'Aquino', 'Ramos', DATE '1984-01-06', 'PSA-1980-9988', 2);
INSERT INTO customers (customer_id, first_name, middle_name, last_name, dob, government_id, kyc_tier) VALUES ('usr-2008-cst-008', 'Apolinario', 'Marasigan', 'Mabini', DATE '1986-07-23', 'PSA-1984-7766', 2);

INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3001', 'usr-1001-cst-001', '1000-2000-3001');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3002', 'usr-1002-cst-002', '1000-2000-3002');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('acc-2001-sav-001', 'usr-1001-cst-001', '100100001234');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('acc-2002-sav-001', 'usr-1001-cst-001', '100100005678');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('acc-2003-sav-002', 'usr-1002-cst-002', '100200009999');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3004', 'usr-2003-cst-003', '1000-2000-3004');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3005', 'usr-2004-cst-004', '1000-2000-3005');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3006', 'usr-2005-cst-005', '1000-2000-3006');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3007', 'usr-2006-cst-006', '1000-2000-3007');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3008', 'usr-2007-cst-007', '1000-2000-3008');
INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('1000-2000-3009', 'usr-2008-cst-008', '1000-2000-3009');

INSERT INTO accounts (account_id, customer_id, account_number) VALUES ('T24-CLEARING-SUSPENSE', 'cif-0000-ext-clr', 'T24-CLEARING-SUSPENSE');
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('T24-CLEARING-SUSPENSE', 0, 0, 0);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3001', 25000000, 0, 25000000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3002', 5000000, 0, 5000000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('acc-2001-sav-001', 25000000, 5000000, 20000000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('acc-2002-sav-001', 8500000, 0, 8500000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('acc-2003-sav-002', 1150000, 0, 1150000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3004', 5200000, 0, 5200000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3005', 3750000, 0, 3750000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3006', 4200000, 0, 4200000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3007', 6800000, 0, 6800000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3008', 2950000, 0, 2950000);
INSERT INTO balance_master (account_id, balance_amount, hold_amount, available_balance) VALUES ('1000-2000-3009', 9100000, 0, 9100000);

INSERT INTO transactions (transaction_id, from_account_id, to_account_id, type, amount, before_balance, after_balance, status, requires_2fa_otp, location_name, latitude, longitude)
VALUES ('tx-4001-hld-001', 'acc-2001-sav-001', 'acc-2003-sav-002', 'TRANSFER', 5000000, 25000000, 25000000, 'PENDING_APPROVAL', 1, 'Manila, Philippines', 14.5995, 120.9842);
INSERT INTO transactions (transaction_id, from_account_id, to_account_id, type, amount, before_balance, after_balance, status, requires_2fa_otp, approved_by_user_id)
VALUES ('tx-4002-cmt-002', 'acc-2002-sav-001', 'acc-2003-sav-002', 'TRANSFER', 150000, 8650000, 8500000, 'COMMITTED', 0, 'stf-1003-ops-001');
INSERT INTO transactions (transaction_id, from_account_id, to_account_id, type, amount, before_balance, after_balance, status, requires_2fa_otp, approved_by_user_id)
VALUES ('tx-4003-otc-003', 'acc-2001-sav-001', NULL, 'WITHDRAWAL', 50000, 25050000, 25000000, 'COMMITTED', 0, 'stf-1003-ops-001');

INSERT INTO outbox_events (event_id, aggregate_type, aggregate_id, event_type, kafka_topic, payload, status, retry_count, published_at)
VALUES ('evt-5002-tx-002', 'TRANSACTION', 'tx-4002-cmt-002', 'MUTATION_COMMITTED', 'banking.transfers.events',
        '{"transactionId":"tx-4002-cmt-002","fromAccount":"acc-2002-sav-001","toAccount":"acc-2003-sav-002","amount":150000.0000,"status":"COMMITTED"}',
        'PUBLISHED', 0, CURRENT_TIMESTAMP);

COMMIT;
