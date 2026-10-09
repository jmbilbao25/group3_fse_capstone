-- =============================================================================
-- AURA_BFF: digital channel data, owned by account-service (auth, e-KYC,
-- device telemetry) and notification-service (alerts, push tokens).
-- Customer logins only; staff live in AURA_ADMIN.
-- user_id equals the customer's AURA_CORE customer_id (CIF).
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE;
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = aura_bff;

CREATE TABLE app_users (
    user_id                  VARCHAR2(64) PRIMARY KEY,
    first_name               VARCHAR2(100) NOT NULL,
    middle_name              VARCHAR2(100),
    last_name                VARCHAR2(100) NOT NULL,
    email                    VARCHAR2(255) NOT NULL UNIQUE,
    phone_number             VARCHAR2(30) NOT NULL UNIQUE,
    dob                      DATE NOT NULL,
    government_id            VARCHAR2(100) NOT NULL,
    role                     VARCHAR2(20) DEFAULT 'CUSTOMER' NOT NULL,
    password_hash            VARCHAR2(255) NOT NULL,
    pin_hash                 VARCHAR2(255),
    max_concurrent_sessions  NUMBER(3) DEFAULT 3 NOT NULL,
    failed_login_attempts    NUMBER(3) DEFAULT 0 NOT NULL,
    status                   VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    kyc_status               VARCHAR2(30) DEFAULT 'PENDING' NOT NULL,
    kyc_review_reason        VARCHAR2(500),
    -- Device telemetry: the customer's current location as last reported by the
    -- app, or as moved by the admin geo simulator for demos.
    last_known_latitude      NUMBER(10, 6) DEFAULT 14.5995,
    last_known_longitude     NUMBER(10, 6) DEFAULT 120.9842,
    last_known_location_name VARCHAR2(100) DEFAULT 'Manila, Philippines',
    last_known_ip            VARCHAR2(45) DEFAULT '112.198.45.10',
    last_geo_updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at            TIMESTAMP WITH TIME ZONE,
    created_at               TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at               TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_app_role CHECK (role = 'CUSTOMER'),
    CONSTRAINT chk_app_status CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED')),
    CONSTRAINT chk_app_kyc CHECK (kyc_status IN ('PENDING', 'PENDING_REVIEW', 'VERIFIED', 'REJECTED'))
);

-- One row per e-KYC attempt. Laya fills the evaluation; a person decides.
-- The maker/checker trail itself lives in AURA_ADMIN.review_cases; only the
-- final outcome is copied back here.
CREATE TABLE kyc_submissions (
    submission_id     VARCHAR2(64) PRIMARY KEY,
    user_id           VARCHAR2(64) NOT NULL,
    id_type           VARCHAR2(40) NOT NULL,
    front_blob_path   VARCHAR2(255) NOT NULL,
    back_blob_path    VARCHAR2(255),
    selfie_blob_path  VARCHAR2(255) NOT NULL,
    laya_decision     VARCHAR2(20) NOT NULL,
    confidence_score  NUMBER(5, 2) NOT NULL,
    face_similarity   NUMBER(5, 4),
    liveness_score    NUMBER(5, 4),
    ocr_confidence    NUMBER(5, 4),
    ocr_full_name     VARCHAR2(200),
    ocr_dob           VARCHAR2(20),
    ocr_id_number     VARCHAR2(60),
    laya_flags        VARCHAR2(1000),
    laya_summary      VARCHAR2(2000) NOT NULL,
    status            VARCHAR2(20) DEFAULT 'PENDING_REVIEW' NOT NULL,
    approved_tier     NUMBER(1),
    decided_by        VARCHAR2(64),
    decision_note     VARCHAR2(500),
    decided_at        TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_kyc_user FOREIGN KEY (user_id) REFERENCES app_users(user_id),
    CONSTRAINT chk_kyc_laya CHECK (laya_decision IN ('APPROVED', 'PENDING_REVIEW', 'REJECTED')),
    CONSTRAINT chk_kyc_status CHECK (status IN ('PENDING_REVIEW', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_kyc_tier CHECK (approved_tier IS NULL OR approved_tier BETWEEN 1 AND 3)
);

-- FCM registration per bound device; the device id matches the session store.
CREATE TABLE device_push_tokens (
    device_id   VARCHAR2(128) PRIMARY KEY,
    user_id     VARCHAR2(64) NOT NULL,
    push_token  VARCHAR2(512) NOT NULL,
    platform    VARCHAR2(20) NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_push_user FOREIGN KEY (user_id) REFERENCES app_users(user_id),
    CONSTRAINT chk_push_platform CHECK (platform IN ('ANDROID', 'IOS', 'WEB'))
);

CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    user_id         VARCHAR2(64) NOT NULL,
    type            VARCHAR2(50) NOT NULL,
    message         CLOB NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_notif_type CHECK (type IN ('TRANSACTION_ALERT', 'SECURITY_ALERT', 'CUSTOMER_VERIFICATION_ALERT', 'AMLA_CTR_ALERT'))
);

CREATE INDEX idx_kyc_status ON kyc_submissions(status, created_at);
CREATE INDEX idx_kyc_user ON kyc_submissions(user_id, created_at DESC);
CREATE INDEX idx_push_user ON device_push_tokens(user_id);
CREATE INDEX idx_notif_user ON notifications(user_id, sent_at DESC);

-- -----------------------------------------------------------------------------
-- Seed: customers only. Demo password for every account is "password123".
-- -----------------------------------------------------------------------------
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, pin_hash, kyc_status)
VALUES ('usr-1001-cst-001', 'Juan', 'Santos', 'Dela Cruz', 'juan.dc@email.com', '+639171234567', DATE '1990-05-15', 'PASSPORT-P9876543A',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 'VERIFIED');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, pin_hash, kyc_status)
VALUES ('usr-1002-cst-002', 'Maria', 'Clara', 'Reyes', 'maria.reyes@eastwestbanker.com', '+639189876543', DATE '1992-08-20', 'UMID-0111-2233445-6',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', '$2a$10$e8V9m5gQ4F9oY9o8O8V7eeY9o8O8V7ee', 'VERIFIED');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2003-cst-003', 'Jose', 'Protacio', 'Rizal', 'jose.rizal@retailbank.ph', '+639195556677', DATE '1987-06-19', 'PRC-1861-1234',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 14.2117, 121.1656, 'Calamba, Laguna, Philippines', '112.198.33.15');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2004-cst-004', 'Andres', 'Castro', 'Bonifacio', 'andres.bonifacio@retailbank.ph', '+639173334455', DATE '1989-11-30', 'PSA-1863-1130',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 7.1907, 125.4578, 'Davao City, Philippines', '112.198.99.77');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2005-cst-005', 'Gabriela', 'Cario', 'Silang', 'gabriela.silang@retailbank.ph', '+639178881122', DATE '1991-03-19', 'PSA-1988-1234',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 17.5705, 120.3878, 'Vigan, Ilocos Sur, Philippines', '112.198.71.12');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2006-cst-006', 'Emilio', 'Dizon', 'Jacinto', 'emilio.jacinto@retailbank.ph', '+639192223344', DATE '1993-12-15', 'PSA-1991-5678',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 14.6760, 121.0437, 'Quezon City, Philippines', '112.198.22.44');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2007-cst-007', 'Melchora', 'Aquino', 'Ramos', 'melchora.aquino@retailbank.ph', '+639174445566', DATE '1984-01-06', 'PSA-1980-9988',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 14.6507, 120.9830, 'Caloocan, Philippines', '112.198.63.89');
INSERT INTO app_users (user_id, first_name, middle_name, last_name, email, phone_number, dob, government_id, password_hash, kyc_status, last_known_latitude, last_known_longitude, last_known_location_name, last_known_ip)
VALUES ('usr-2008-cst-008', 'Apolinario', 'Marasigan', 'Mabini', 'apolinario.mabini@retailbank.ph', '+639187778899', DATE '1986-07-23', 'PSA-1984-7766',
        '$2a$10$4gw7WpRKwOnwNP5i8AQR2e9raJhzryXNsf7Qu.LxSt7alkeeN9nAS', 'VERIFIED', 13.7565, 121.0583, 'Batangas City, Philippines', '112.198.54.33');

INSERT INTO notifications (notification_id, user_id, type, message)
VALUES ('notif-6001-001', 'usr-1001-cst-001', 'TRANSACTION_ALERT', 'Your transfer of PHP 5,000,000.00 is awaiting email verification.');

COMMIT;
