-- ==============================================================================
-- CAPSTONE FSE: Core Retail Ledger & Balance Mutation Engine
-- Epic B: Database & Schema Design (Oracle XE 21c Master Database)
-- File: 05_view_all_data.sql
-- Description: Queries and displays all records from all 7 banking tables.
-- ==============================================================================

SET ECHO OFF;
SET FEEDBACK OFF;
SET DEFINE OFF;
SET LINESIZE 300;
SET PAGESIZE 100;
SET COLSEP ' | ';

COLUMN user_id FORMAT A8;
COLUMN first_name FORMAT A12;
COLUMN last_name FORMAT A14;
COLUMN email FORMAT A22;
COLUMN phone_number FORMAT A13;
COLUMN role FORMAT A10;
COLUMN status FORMAT A10;

COLUMN account_id FORMAT A8;
COLUMN account_number FORMAT A16;
COLUMN account_type FORMAT A10;
COLUMN credit_limit FORMAT 999,999,990.0000;

COLUMN balance_amount FORMAT 999,999,990.0000;
COLUMN hold_amount FORMAT 999,999,990.0000;
COLUMN available_balance FORMAT 999,999,990.0000;

COLUMN transaction_id FORMAT A10;
COLUMN from_account_id FORMAT A15;
COLUMN to_account_id FORMAT A15;
COLUMN type FORMAT A12;
COLUMN amount FORMAT 999,999,990.0000;
COLUMN before_balance FORMAT 999,999,990.0000;
COLUMN after_balance FORMAT 999,999,990.0000;

COLUMN assessment_id FORMAT A10;
COLUMN collateral_type FORMAT A12;
COLUMN credit_score FORMAT 9999;
COLUMN approved_credit_limit FORMAT 999,999,990.0000;
COLUMN risk_tier FORMAT A12;

COLUMN event_id FORMAT A10;
COLUMN aggregate_type FORMAT A16;
COLUMN aggregate_id FORMAT A14;
COLUMN event_type FORMAT A20;
COLUMN kafka_topic FORMAT A20;

COLUMN notification_id FORMAT A10;
COLUMN message FORMAT A60;

PROMPT ==============================================================================
PROMPT 1. TABLE: USERS (Customers, Tellers, Admins)
PROMPT ==============================================================================
SELECT user_id, first_name, last_name, role, email, phone_number, status FROM users;

PROMPT 
PROMPT ==============================================================================
PROMPT 2. TABLE: ACCOUNTS (Bank Accounts and Credit Limits)
PROMPT ==============================================================================
SELECT account_id, user_id, account_number, account_type, credit_limit, status FROM accounts;

PROMPT 
PROMPT ==============================================================================
PROMPT 3. TABLE: BALANCE_MASTER (Live and Available Balances)
PROMPT ==============================================================================
SELECT account_id, balance_amount, hold_amount, available_balance FROM balance_master;

PROMPT 
PROMPT ==============================================================================
PROMPT 4. TABLE: TRANSACTIONS (Operational Mutation Ledger)
PROMPT ==============================================================================
SELECT transaction_id, from_account_id, to_account_id, type, amount, before_balance, after_balance, status FROM transactions;

PROMPT 
PROMPT ==============================================================================
PROMPT 5. TABLE: CREDIT_ASSESSMENTS (Loan Appraisals)
PROMPT ==============================================================================
SELECT assessment_id, account_id, collateral_type, credit_score, approved_credit_limit, risk_tier, status FROM credit_assessments;

PROMPT 
PROMPT ==============================================================================
PROMPT 6. TABLE: OUTBOX_EVENTS (Transactional Outbox)
PROMPT ==============================================================================
SELECT event_id, aggregate_type, aggregate_id, event_type, kafka_topic, status FROM outbox_events;

PROMPT 
PROMPT ==============================================================================
PROMPT 7. TABLE: NOTIFICATIONS (User Alerts)
PROMPT ==============================================================================
SELECT notification_id, user_id, type, message, sent_at FROM notifications;

PROMPT ==============================================================================
