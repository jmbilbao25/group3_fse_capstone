-- =============================================================================
-- AURA_ADMIN: back office, owned by admin-service.
-- Staff identities, the maker/checker trail for every human decision (KYC,
-- SAR/STR, held transfers) and an append-only audit of console actions.
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE;
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = aura_admin;

-- Role decides permissions in admin-service (StaffRole). Segregation of
-- duties: makers and checkers are different roles, and a case can never be
-- checked by the staff member who made it (chk_case_four_eyes).
CREATE TABLE staff_users (
    staff_id       VARCHAR2(64) PRIMARY KEY,
    email          VARCHAR2(255) NOT NULL UNIQUE,
    full_name      VARCHAR2(200) NOT NULL,
    title          VARCHAR2(100) NOT NULL,
    role           VARCHAR2(30) NOT NULL,
    password_hash  VARCHAR2(255) NOT NULL,
    status         VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    last_login_at  TIMESTAMP WITH TIME ZONE,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_staff_role CHECK (role IN ('TELLER', 'OPERATIONS_OFFICER', 'FRAUD_ANALYST', 'BRANCH_MANAGER', 'COMPLIANCE_OFFICER')),
    CONSTRAINT chk_staff_status CHECK (status IN ('ACTIVE', 'DISABLED'))
);

-- One case per subject needing a human decision. subject_id points into the
-- owning schema by value: a BFF kyc submission id or a CORE transaction id.
CREATE TABLE review_cases (
    case_id           VARCHAR2(64) PRIMARY KEY,
    case_type         VARCHAR2(20) NOT NULL,
    subject_id        VARCHAR2(64) NOT NULL,
    customer_id       VARCHAR2(64),
    status            VARCHAR2(20) DEFAULT 'PENDING_MAKER' NOT NULL,
    maker_id          VARCHAR2(64),
    maker_decision    VARCHAR2(10),
    maker_tier        NUMBER(1),
    maker_note        VARCHAR2(500),
    maker_at          TIMESTAMP WITH TIME ZONE,
    checker_id        VARCHAR2(64),
    checker_action    VARCHAR2(10),
    checker_note      VARCHAR2(500),
    checker_at        TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_case_subject UNIQUE (case_type, subject_id),
    CONSTRAINT fk_case_maker FOREIGN KEY (maker_id) REFERENCES staff_users(staff_id),
    CONSTRAINT fk_case_checker FOREIGN KEY (checker_id) REFERENCES staff_users(staff_id),
    CONSTRAINT chk_case_type CHECK (case_type IN ('KYC', 'SAR')),
    CONSTRAINT chk_case_status CHECK (status IN ('PENDING_MAKER', 'PENDING_CHECKER', 'APPROVED', 'REJECTED', 'FILED', 'DISMISSED')),
    CONSTRAINT chk_case_maker_decision CHECK (maker_decision IN ('APPROVE', 'REJECT', 'FILE', 'DISMISS')),
    CONSTRAINT chk_case_checker_action CHECK (checker_action IN ('CONFIRM', 'RETURN')),
    CONSTRAINT chk_case_tier CHECK (maker_tier IS NULL OR maker_tier BETWEEN 1 AND 3),
    CONSTRAINT chk_case_four_eyes CHECK (checker_id IS NULL OR checker_id <> maker_id)
);

-- Append-only. admin-service never updates or deletes these rows, and the
-- trigger below rejects anyone who tries.
CREATE TABLE admin_audit_log (
    audit_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_id      VARCHAR2(64) NOT NULL,
    action        VARCHAR2(50) NOT NULL,
    target_type   VARCHAR2(30) NOT NULL,
    target_id     VARCHAR2(64) NOT NULL,
    detail        VARCHAR2(2000),
    client_ip     VARCHAR2(45),
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE OR REPLACE TRIGGER trg_audit_append_only
BEFORE UPDATE OR DELETE ON admin_audit_log
BEGIN
    RAISE_APPLICATION_ERROR(-20001, 'admin_audit_log is append-only');
END;
/

CREATE INDEX idx_case_queue ON review_cases(case_type, status, created_at);
CREATE INDEX idx_audit_time ON admin_audit_log(created_at DESC);
CREATE INDEX idx_audit_target ON admin_audit_log(target_type, target_id);

-- -----------------------------------------------------------------------------
-- Seed staff. Demo password for every staff account is "password123".
-- -----------------------------------------------------------------------------
INSERT INTO staff_users (staff_id, email, full_name, title, role, password_hash) VALUES
    ('stf-1001-cmp-001', 'diana.admin@bank.com', 'Diana Vance', 'Chief Compliance Officer', 'COMPLIANCE_OFFICER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS');
INSERT INTO staff_users (staff_id, email, full_name, title, role, password_hash) VALUES
    ('stf-1002-mgr-001', 'carlos.mendoza@bank.com', 'Carlos Mendoza', 'Branch Operations Manager', 'BRANCH_MANAGER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS');
INSERT INTO staff_users (staff_id, email, full_name, title, role, password_hash) VALUES
    ('stf-1003-ops-001', 'beatriz.ocampo@bank.com', 'Beatriz Ocampo', 'Customer Onboarding Officer', 'OPERATIONS_OFFICER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS');
INSERT INTO staff_users (staff_id, email, full_name, title, role, password_hash) VALUES
    ('stf-1004-frd-001', 'alex.rivera@bank.com', 'Alex Rivera', 'Fraud and Security Analyst', 'FRAUD_ANALYST', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS');
INSERT INTO staff_users (staff_id, email, full_name, title, role, password_hash) VALUES
    ('stf-1005-tel-001', 'crisostomo.ibarra@bank.com', 'Crisostomo Ibarra', 'Branch Teller', 'TELLER', '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS');

COMMIT;
