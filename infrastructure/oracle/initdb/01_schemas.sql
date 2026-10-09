-- =============================================================================
-- Aura Bank: one Oracle PDB, three schemas, one owner per bounded context.
--
--   AURA_CORE   core banking (T24 role): customers, accounts, balances, ledger
--   AURA_BFF    digital channel: app logins, devices, e-KYC submissions, push
--   AURA_ADMIN  back office: staff, maker/checker review cases, audit trail
--
-- Each service connects with its own user and can only see its own schema.
-- There are no cross-schema grants or foreign keys: services reference each
-- other's ids (customer_id, submission_id, transaction_id) and talk over HTTP.
-- Runs as SYS on first container start (gvenzl/oracle-xe initdb hook).
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE;
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER aura_core  IDENTIFIED BY "core_password"  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
CREATE USER aura_bff   IDENTIFIED BY "bff_password"   DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
CREATE USER aura_admin IDENTIFIED BY "admin_password" DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

-- Owners need DDL for their own objects and nothing else.
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER TO aura_core;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER TO aura_bff;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER TO aura_admin;
