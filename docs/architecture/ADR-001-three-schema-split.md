# ADR-001: Split the shared database into core, channel and back-office schemas

Status: Accepted (October 2026)

## Context

Every service connected to one Oracle schema (`fse_user`) as the same user. The
app's login table, the core ledger, staff accounts and audit all lived side by
side, any service could write any table, and the `users` table mixed customers
with administrators. A real bank does not run its channel and its core banking
system (T24) on one schema: the core is the system of record and is reached
through its own interface.

## Decision

One Oracle PDB (`XEPDB1`) with three schemas, each owned by its own database
user. A service only has the credentials for the schema it owns.

| Schema | Owner service | Holds |
|---|---|---|
| `AURA_CORE` | ledger-mutation-engine | Customer master (CIF) with KYC tier, tier limits, savings accounts, balances, transactions, outbox |
| `AURA_BFF` | account-service, notification-service | Customer logins and credentials, device telemetry (current location), e-KYC submissions and Laya results, push tokens, notifications |
| `AURA_ADMIN` | admin-service (new) | Staff users and roles, maker/checker review cases (KYC, SAR/STR), append-only console audit log |

The PostgreSQL audit vault (immutable ledger journal) is unchanged.

Rules:

1. **No cross-schema grants or foreign keys.** Ids cross boundaries by value:
   a BFF `user_id` equals the core `customer_id`; a core transaction stores the
   approving staff id as text.
2. **Services talk over HTTP, not SQL.** Internal endpoints live under
   `/api/v1/internal/**` and `/api/v1/core/**`; the gateway does not route
   them, so they are only reachable inside the cluster network.
3. **The core decides money.** Transfer limits are enforced in the ledger
   from the customer's KYC tier, never only in the app.
4. **People decide identity and filings.** Laya scores every KYC submission
   and drafts SAR/STRs, but nothing is approved or filed without a maker and a
   different checker (enforced in admin-service and by a database check).

## Request flows

- **Registration**: app -> account-service `POST /auth/register` creates the
  BFF login (KYC `PENDING`) and calls core `POST /core/customers` to open the
  CIF at Tier 0 with a savings account. Tier 0 can receive, not send.
- **e-KYC**: app uploads ID and selfie, account-service stores the Laya result
  in `kyc_submissions` (`PENDING_REVIEW`, always). Admin maker recommends
  approve/reject and a tier; a different checker confirms. admin-service then
  calls account-service, which marks the login `VERIFIED` and asks the core to
  raise the CIF tier.
- **Transfer**: app -> ledger. The ledger reads the customer's current
  location from account-service (`GET /internal/v1/users/{id}/location`,
  short timeout, safe fallback), checks the tier limits, runs geo-velocity
  and Laya, then settles, soft-holds for OTP, or soft-holds for compliance.
- **Geo demo**: admin moves a customer (admin-service ->
  account-service `PATCH /users/{id}/location`); the next transfer is measured
  against the previous located transfer and held as impossible travel.

## KYC tiers

Modelled on Philippine practice (sources below). Stored in
`AURA_CORE.kyc_tier_limits`, so limits change without a deploy.

| Tier | Name | Per transfer | Daily | Monthly | Reached by |
|---|---|---|---|---|---|
| 0 | Unverified | 0 | 0 | 0 | Registration |
| 1 | Basic | 10,000 | 20,000 | 50,000 | One valid ID + selfie, approved as basic |
| 2 | Verified | 50,000 | 200,000 | 1,000,000 | Full e-KYC approved |
| 3 | Premier | 5,000,000 | 10,000,000 | 50,000,000 | Enhanced due diligence approved |

- Tier 1 follows the BSP basic deposit account (simplified KYC, PHP 50,000
  balance cap) and e-wallet basic tiers such as Maya's PHP 50,000 monthly limit.
- Tier 2 uses the PHP 50,000 InstaPay per-transfer cap and the PHP 200,000
  daily digital aggregate published by banks such as EastWest and PNB.
- Tier 3 sits above the BSP Circular 1230 PHP 1,000,000 daily cash threshold,
  which is why it requires enhanced due diligence.

Existing controls still apply on top: transfers above PHP 50,000 need customer
OTP, and PHP 500,000 and above need two approvers.

## Consequences

- Each service config now has its own DB user and password.
- account-service no longer reads accounts or balances from SQL; it calls the
  core API. Customer-facing `/api/v1/accounts/**` is unchanged for the app.
- Staff log in to the console through admin-service, not the customer login.
- Old single-schema scripts (`init.sql`, `00`-`05_*.sql`, migration and study
  guides describing them) are removed; `infrastructure/oracle/initdb/` is the
  only source of truth.

## Sources

- BSP Circular 992, Basic Deposit Account framework (PHP 50,000 cap)
- [Maya account limits](https://www.maya.ph/account-limits)
- [EastWest InstaPay terms](https://www.eastwestbanker.com/instapay-terms-and-conditions)
- [PNB digital banking limits](https://www.pnb.com.ph/index.php/pnb-digital-banking-send-money)
- [Metrobank on BSP Circular 1230](https://www.metrobank.com.ph/articles/new-bsp-rules-on-large-value-transactions)
