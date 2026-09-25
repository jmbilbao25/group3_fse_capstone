# Requirements: Account & Identity Microservice (account-service)

## 1. Domain Glossary

- Account Service: The microservice running on port 8081 responsible for identity management, authentication, customer KYC onboarding, account provisioning, and cached balance inquiry.
- User Profile: Relational record in the users table holding customer identity, credentials hash, contact details, role, and operational status.
- Account Provisioning: The administrative workflow of issuing a bank account record with a 12-digit account number and creating an associated balance master row.
- Balance Master: Relational record in Oracle XE tracking the current balance, held balance, and available balance with precision NUMBER(18, 4).
- Refresh Token Rotation (RTR): Security mechanism where every token refresh invalidates the used refresh token and issues a new single-use refresh token.
- Token Family: A collection of refresh tokens originating from a single login session, tracked in Redis to detect replay attacks.
- Breach Detection: The security rule where presenting an already revoked refresh token triggers immediate invalidation of all tokens within that session family.
- Session Store: In-memory Redis store tracking active token IDs per user to enforce concurrent login limits.
- Problem Details: Standardized error representation conforming to RFC-7807.

## 2. Scope Boundaries

- In-Scope:
  - Customer registration with JSR-380 input validation and BCrypt password hashing.
  - User authentication issuing 15-minute access JWTs and single-use 7-day refresh tokens via HttpOnly cookies.
  - Refresh Token Rotation with token family tracking and breach detection in Redis.
  - Logout workflow invalidating access tokens in Redis blacklist and purging token families.
  - Concurrent session limit enforcement against the users table configuration.
  - Account provisioning for Savings, Checking, and Credit types with unique 12-digit account numbers.
  - Atomic initialization of balance_master rows upon account creation.
  - Account status update endpoint for administrative locking or activation.
  - Account listing by customer identity.
  - Account balance inquiry with 30-second Redis read-through caching.
  - Administrative KYC inspection, profile approval, and profile rejection endpoints.
  - Shared domain contracts, enums, DTOs, and RFC-7807 exception advice.
- Out-of-Scope (handled by other team services):
  - Core balance mutations, pessimistic row locks, and ledger debits/credits (handled by ledger-mutation-engine on port 8082).
  - High-value transfer Maker-Checker workflow and Kafka outbox publication (handled by ledger-mutation-engine on port 8082).
  - Push notifications, SMS alerts, and receipt formatting (handled by notification-service on port 8083).
  - API Gateway perimeter routing, global rate limiting, and edge token filtering (handled by gateway-service on port 8080).
  - Audit trail ingestion into PostgreSQL (handled by audit workers on port 5432).

## 3. Requirements and EARS Acceptance Criteria

### Requirement 1: Customer Registration and KYC Ingestion
User Story: As a prospective customer, I want to submit my personal identity and government identification details so that the bank can establish my verified customer profile.

- Ubiquitous Criteria:
  - REQ-1.1: THE Account Service SHALL validate customer registration fields via JSR-380 annotations, ensuring required names, valid email format, positive phone digits, and government ID inputs.
  - REQ-1.2: THE Account Service SHALL hash user passwords using BCrypt with a minimum cost factor of 10 prior to database persistence.
  - REQ-1.3: THE Account Service SHALL assign the default role of CUSTOMER and initial status of ACTIVE with KYC status set to PENDING on new registrations.
- Event-Driven Criteria:
  - REQ-1.4: WHEN a registration payload passes validation and contains unique identity credentials, THE Account Service SHALL insert a record into the users table and return HTTP 201 Created with user_id, email, kyc_status, and created_at.
- Unwanted Behavior Criteria:
  - REQ-1.5: IF a registration request provides an email or phone number that matches an existing record, THEN THE Account Service SHALL reject the request with HTTP 409 Conflict formatted as an RFC-7807 problem detail.
  - REQ-1.6: IF any required field fails format validation, THEN THE Account Service SHALL return HTTP 400 Bad Request with an array of invalid parameters detailing rejected fields.

### Requirement 2: Authentication and Token Lifecycle
User Story: As a customer or staff member, I want to log in using my registered credentials so that I receive an authenticated session token for API operations.

- Ubiquitous Criteria:
  - REQ-2.1: THE Account Service SHALL issue an HMAC-SHA256 signed JWT access token having an expiration window of exactly 15 minutes (900 seconds), containing claims for sub (user_id), email, role, and jti (JWT ID).
  - REQ-2.2: THE Account Service SHALL issue a single-use refresh token with an expiration of 7 days (604800 seconds) delivered in an HttpOnly, SameSite=Strict cookie with path /api/v1/auth.
- Event-Driven Criteria:
  - REQ-2.3: WHEN login credentials match an active user record, THE Account Service SHALL reset failed_login_attempts to zero, record the session in Redis, and return HTTP 200 OK with the access token and role metadata.
  - REQ-2.4: WHEN the number of active sessions for a user equals or exceeds max_concurrent_sessions, THE Account Service SHALL evict the oldest active token jti by adding it to the Redis blacklist before granting the new session.
- Unwanted Behavior Criteria:
  - REQ-2.5: IF invalid credentials are submitted, THEN THE Account Service SHALL increment failed_login_attempts, return HTTP 401 Unauthorized, and lock the user account when failed attempts reach 5.
  - REQ-2.6: IF a user with status LOCKED or SUSPENDED attempts authentication, THEN THE Account Service SHALL reject the request with HTTP 403 Forbidden.

### Requirement 3: Refresh Token Rotation and Breach Detection
User Story: As a security engineer, I want refresh tokens rotated on every renewal and previous tokens invalidated so that credential replay attacks are detected and blocked.

- Ubiquitous Criteria:
  - REQ-3.1: THE Account Service SHALL maintain token family lineage in Redis associating all refresh tokens derived from a single login event.
- Event-Driven Criteria:
  - REQ-3.2: WHEN an active refresh token is presented at /api/v1/auth/refresh, THE Account Service SHALL mark that token as REVOKED, issue a new rotated refresh token in the cookie, issue a new access token, and return HTTP 200 OK within 15 milliseconds.
- Unwanted Behavior Criteria:
  - REQ-3.3: IF a revoked or consumed refresh token is presented at /api/v1/auth/refresh, THEN THE Account Service SHALL detect a replay breach, delete all refresh tokens and sessions belonging to that token family from Redis, and return HTTP 401 Unauthorized with error code TOKEN_BREACH_DETECTED.

### Requirement 4: Session Logout and Access Token Blacklisting
User Story: As an authenticated user, I want to log out so that my current session and access tokens are immediately revoked.

- Ubiquitous Criteria:
  - REQ-4.1: THE Account Service SHALL push the access token jti into the Redis blacklist key auth:blacklist:{jti} with a TTL matching the remaining token lifetime.
  - REQ-4.2: THE Account Service SHALL delete the active refresh token, token family, and session metadata from Redis.
  - REQ-4.3: THE Account Service SHALL clear the refresh token cookie by returning a Set-Cookie header with Max-Age=0.

### Requirement 5: Bank Account Provisioning and Management
User Story: As an administrator, I want to provision bank accounts for verified customers so that they can hold funds and conduct transactions.

- Ubiquitous Criteria:
  - REQ-5.1: THE Account Service SHALL generate a unique 12-digit numeric account number for every provisioned account.
  - REQ-5.2: THE Account Service SHALL support account types of SAVINGS, CHECKING, and CREDIT.
  - REQ-5.3: THE Account Service SHALL insert an initial record in balance_master with balance_amount equal to the initial deposit, hold_amount equal to 0.0000, and available_balance equal to balance_amount, using precision NUMBER(18, 4).
- Event-Driven Criteria:
  - REQ-5.4: WHEN an administrator submits an account creation request for an active customer, THE Account Service SHALL persist the account and balance records within a single database transaction and return HTTP 201 Created.
  - REQ-5.5: WHEN an administrator updates account status via /api/v1/accounts/{id}/status, THE Account Service SHALL update the accounts table, invalidate the Redis balance cache for that account, and return HTTP 200 OK.
- Unwanted Behavior Criteria:
  - REQ-5.6: IF an administrator attempts to provision an account for a non-existent or inactive user_id, THEN THE Account Service SHALL reject the request with HTTP 404 Not Found or HTTP 400 Bad Request.

### Requirement 6: Account Listing and Cached Balance Inquiry
User Story: As a customer or banking staff member, I want to inspect account balances rapidly so that user dashboards load without database latency.

- Ubiquitous Criteria:
  - REQ-6.1: THE Account Service SHALL return balance figures with exact 4-decimal precision representing current_balance, held_balance, and available_balance.
- Event-Driven Criteria:
  - REQ-6.2: WHEN a balance inquiry arrives for an account ID, THE Account Service SHALL query Redis key account:balance:{id}. If the key exists, it SHALL return the payload with cached=true.
  - REQ-6.3: WHEN a balance inquiry misses the Redis cache, THE Account Service SHALL query the balance_master and accounts tables, populate the Redis key with a 30-second TTL, and return the payload with cached=false.
- Unwanted Behavior Criteria:
  - REQ-6.4: IF a balance inquiry references an account ID that does not exist, THEN THE Account Service SHALL return HTTP 404 Not Found formatted as an RFC-7807 problem detail.

### Requirement 7: Administrative KYC Verification Queue
User Story: As an administrator, I want to review pending customer profiles and approve or reject their KYC status.

- Ubiquitous Criteria:
  - REQ-7.1: THE Account Service SHALL expose an endpoint to retrieve customers having status ACTIVE or PENDING review.
  - REQ-7.2: THE Account Service SHALL provide an approval action that sets the verified KYC flag and records the reviewing administrator ID.
  - REQ-7.3: THE Account Service SHALL provide a rejection action that sets user status to SUSPENDED or LOCKED and stores the rejection justification.
