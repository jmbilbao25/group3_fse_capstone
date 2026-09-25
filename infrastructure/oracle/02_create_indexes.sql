-- ==============================================================================
-- CAPSTONE FSE: Core Retail Ledger & Balance Mutation Engine
-- Epic B: Database & Schema Design (Oracle XE 21c Master Database)
-- File: 02_create_indexes.sql
-- Description: Creates performance-optimized B-Tree indexes for foreign keys,
--              high-frequency lookup paths, and concurrent query processing.
-- ==============================================================================

SET ECHO ON;
SET FEEDBACK ON;

-- ------------------------------------------------------------------------------
-- 1. FOREIGN KEY INDEXES
-- Critical Oracle Best Practice:
-- Prevents full table share locks (TM locks) on child tables during updates/deletes.
-- ------------------------------------------------------------------------------

-- Index on ACCOUNTS(user_id)
CREATE INDEX idx_accounts_user_id 
    ON accounts (user_id);

-- Index on TRANSACTIONS foreign keys
CREATE INDEX idx_txn_from_account 
    ON transactions (from_account_id);

CREATE INDEX idx_txn_to_account 
    ON transactions (to_account_id);

CREATE INDEX idx_txn_approved_by 
    ON transactions (approved_by_user_id);

-- Index on CREDIT_ASSESSMENTS foreign keys
CREATE INDEX idx_ca_account_id 
    ON credit_assessments (account_id);

CREATE INDEX idx_ca_user_id 
    ON credit_assessments (user_id);

CREATE INDEX idx_ca_teller_id 
    ON credit_assessments (assessed_by_teller_id);

-- Index on OUTBOX_EVENTS(aggregate_id)
CREATE INDEX idx_outbox_aggregate 
    ON outbox_events (aggregate_id);

-- Index on NOTIFICATIONS(user_id)
CREATE INDEX idx_notif_user_id 
    ON notifications (user_id);


-- ------------------------------------------------------------------------------
-- 2. QUERY OPTIMIZATION INDEXES (HIGH-FREQUENCY LOOKUPS)
-- Accelerates transaction queries, outbox polling, and dashboard rendering.
-- ------------------------------------------------------------------------------

-- Composite index for account statement & transaction history
CREATE INDEX idx_txn_from_acct_created 
    ON transactions (from_account_id, created_at DESC);

CREATE INDEX idx_txn_to_acct_created 
    ON transactions (to_account_id, created_at DESC);

-- Index for Maker-Checker review queue
CREATE INDEX idx_txn_pending_approval 
    ON transactions (status, requires_maker_checker, created_at ASC);

-- Index for Transactional Outbox Polling
CREATE INDEX idx_outbox_pending_dispatch 
    ON outbox_events (status, retry_count, created_at ASC);

-- Index for Notifications list by user (ordered by latest)
CREATE INDEX idx_notif_user_sent 
    ON notifications (user_id, sent_at DESC);
