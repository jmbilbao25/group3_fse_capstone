-- ==============================================================================
-- CAPSTONE FSE: Core Retail Ledger & Balance Mutation Engine
-- Epic B: Database & Schema Design (Oracle XE 21c Master Database)
-- File: 00_master_setup.sql
-- Description: Master execution script matching the official Group 3
--              Definitive Architecture, Schemas, and Source of Truth.
-- ==============================================================================

PROMPT ====================================================================
PROMPT Step 1: Cleaning up existing tables...
PROMPT ====================================================================
@@04_cleanup_schema.sql

PROMPT ====================================================================
PROMPT Step 2: Creating master tables, foreign keys, and check constraints...
PROMPT ====================================================================
@@01_create_tables_and_constraints.sql

PROMPT ====================================================================
PROMPT Step 3: Creating performance and foreign key indexes...
PROMPT ====================================================================
@@02_create_indexes.sql

PROMPT ====================================================================
PROMPT Step 4: Seeding sample data for testing...
PROMPT ====================================================================
@@03_seed_sample_data.sql

PROMPT ====================================================================
PROMPT Verification Query: Row counts in all tables
PROMPT ====================================================================
SELECT 'USERS' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'ACCOUNTS', COUNT(*) FROM accounts
UNION ALL
SELECT 'BALANCE_MASTER', COUNT(*) FROM balance_master
UNION ALL
SELECT 'CREDIT_ASSESSMENTS', COUNT(*) FROM credit_assessments
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM transactions
UNION ALL
SELECT 'OUTBOX_EVENTS', COUNT(*) FROM outbox_events
UNION ALL
SELECT 'NOTIFICATIONS', COUNT(*) FROM notifications;

PROMPT ====================================================================
PROMPT Epic B (FSE-201) Oracle XE Schema Setup Complete!
PROMPT ====================================================================
