# Tasks: Account & Identity Microservice (account-service)

This document defines actionable, sequential implementation steps for the Account Service module.

---

## Task Checklist

- [x] **Task 1: Establish Common Contracts and Shared DTOs**
  - Path: `backend/common-contracts/src/main/java/com/fse/banking/common/`
  - Subtasks:
    - Create domain enums: `AccountType`, `AccountStatus`, `UserRole`, `KycStatus` in package `enums`.
    - Create RFC-7807 problem details classes: `ProblemDetails`, `InvalidParam` in package `dto`.
    - Create base banking exceptions: `ResourceNotFoundException`, `ConflictException`, `TokenBreachException`, `UnauthorizedException`, `ForbiddenException`, `ValidationException` in package `exception`.
  - _Requirements: REQ-1.5, REQ-1.6, REQ-3.3, REQ-5.2; Design: Section 1, Section 3_

- [x] **Task 2: Configure Maven Dependencies and Spring Environment**
  - Path: `backend/account-service/pom.xml`, `backend/account-service/src/main/resources/application.properties`
  - Subtasks:
    - Update `account-service/pom.xml` to include `spring-boot-starter-data-redis`, `spring-security-crypto`, `jjwt-api`, `jjwt-impl`, `jjwt-jackson`, and test dependencies (`h2`, `spring-boot-starter-test`).
    - Update `application.properties` with Redis connection properties, JWT signing secret, token expiration properties, and cookie flags.
    - Set up `TestSecurityConfig` or test profile properties for in-memory H2 repository testing.
  - _Requirements: REQ-2.1, REQ-2.2, REQ-4.1; Design: Section 3_

- [x] **Task 3: Implement Domain Entities and Spring Data Repositories**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/model/`, `.../repository/`
  - Subtasks:
    - Create `UserEntity` mapped to `users` table: fields `userId`, `firstName`, `lastName`, `middleName`, `email`, `phoneNumber`, `dob`, `governmentId`, `role`, `passwordHash`, `pinHash`, `maxConcurrentSessions`, `failedLoginAttempts`, `status`, `createdAt`, `updatedAt`.
    - Create `AccountEntity` mapped to `accounts` table: fields `accountId`, `userId`, `accountNumber`, `accountType`, `status`, `creditLimit`, `createdAt`, `updatedAt`.
    - Create `BalanceMasterEntity` mapped to `balance_master` table: fields `accountId`, `balanceAmount`, `holdAmount`, `availableBalance`, `createdAt`, `updatedAt` with `BigDecimal` scale 4 and precision 18.
    - Create `UserRepository` with query methods `findByEmail`, `existsByEmail`, `existsByPhoneNumber`, `existsByGovernmentId`, `findByStatus`.
    - Create `AccountRepository` with query methods `findByUserId`, `findByAccountNumber`, `existsByAccountNumber`.
    - Create `BalanceMasterRepository` with query method `findByAccountId`.
  - _Requirements: REQ-1.1, REQ-1.4, REQ-5.1, REQ-5.3, REQ-6.1; Design: Section 1, Section 4_

- [x] **Task 4: Implement Redis Session Store and JWT Provider Adapter**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/security/`
  - Subtasks:
    - Create `JwtProvider` component generating HMAC-SHA256 tokens with claims (`sub`, `email`, `role`, `jti`, `iat`, `exp`) and validating signatures.
    - Create `RedisSessionStore` service managing:
      - Token blacklist set: `auth:blacklist:{jti}` with TTL.
      - User active session set: `auth:user-sessions:{userId}` enforcing `max_concurrent_sessions`.
      - Refresh token hash: `refresh_token:{token}` (`status`, `userId`, `sessionId`, `role`, `parentTokenId`).
      - Token family set: `token_family:{sessionId}` for breach detection.
      - Balance read cache: `account:balance:{accountId}` with 30s TTL.
  - _Requirements: REQ-2.1, REQ-2.2, REQ-2.4, REQ-3.1, REQ-4.1, REQ-4.2; Design: Section 1, Section 2_

- [x] **Task 5: Implement Authentication Service and Token Rotation Logic**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/service/`
  - Subtasks:
    - Implement `AuthService`:
      - `register(RegisterRequest)`: validate uniqueness, hash password via BCrypt, persist user, return response.
      - `login(LoginRequest)`: check credentials, verify user status, check failed login counter, enforce session limit in Redis, issue JWT access token and single-use refresh token.
      - `logout(String bearerToken, String refreshToken)`: extract JTI, blacklist access token in Redis, delete token family and session keys.
    - Implement `TokenRotationService`:
      - `rotateRefreshToken(String refreshTokenValue)`: check Redis status; if REVOKED, purge entire token family and throw `TokenBreachException`; if ACTIVE, mark old token REVOKED, generate rotated refresh token and new access token.
  - _Requirements: REQ-1.1 through REQ-4.3; Design: Section 2_

- [x] **Task 6: Implement Account Provisioning and Balance Inquiry Services**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/service/`
  - Subtasks:
    - Implement `AccountProvisioningService`:
      - `provisionAccount(CreateAccountRequest)`: validate customer, generate unique 12-digit account number, persist `AccountEntity`, persist initial `BalanceMasterEntity` with exact 4-decimal precision in a single `@Transactional` boundary.
      - `updateAccountStatus(String accountId, AccountStatus status)`: update status, invalidate Redis balance cache.
      - `getAccountsByUser(String userId)`: return account summaries with current balances.
    - Implement `BalanceInquiryService`:
      - `getBalance(String accountId)`: inspect Redis cache `account:balance:{accountId}`; if hit, return with `cached=true`; if miss, load from database, store in Redis with 30s TTL, return with `cached=false`.
    - Implement `KycService`:
      - `listPendingKyc()`: retrieve users with pending verification status.
      - `approveKyc(String userId, String reviewerId)`: activate profile and record approval.
      - `rejectKyc(String userId, String reviewerId, String reason)`: suspend profile with notes.
  - _Requirements: REQ-5.1 through REQ-7.3; Design: Section 2, Section 4_

- [x] **Task 7: Implement REST Controllers and RFC-7807 Global Exception Handler**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/controller/`, `.../exception/`
  - Subtasks:
    - Create `AuthController`:
      - `POST /api/v1/auth/register` (returns 201 Created)
      - `POST /api/v1/auth/login` (sets HttpOnly cookie, returns 200 OK)
      - `POST /api/v1/auth/refresh` (rotates cookie, returns 200 OK or 401 on breach)
      - `POST /api/v1/auth/logout` (clears cookie, returns 200 OK)
    - Create `AccountController`:
      - `POST /api/v1/accounts` (provision account, returns 201 Created)
      - `PATCH /api/v1/accounts/{accountId}/status` (updates status, returns 200 OK)
      - `GET /api/v1/accounts` (lists accounts for customer, returns 200 OK)
      - `GET /api/v1/accounts/{accountId}/balance` (cached inquiry, returns 200 OK)
    - Create `KycController`:
      - `GET /api/v1/kyc/pending`
      - `POST /api/v1/kyc/{userId}/approve`
      - `POST /api/v1/kyc/{userId}/reject`
    - Create `GlobalExceptionHandler`:
      - Translate validation errors to RFC-7807 problem details with `invalid_params`.
      - Translate `TokenBreachException` to 401 with breach diagnostic detail.
      - Translate `ConflictException` to 409, `ResourceNotFoundException` to 404, `LockedUserException` to 403.
  - _Requirements: REQ-1.5, REQ-1.6, REQ-2.5, REQ-2.6, REQ-3.3, REQ-6.4; Design: Section 1_

- [x] **Task 8: Comprehensive Automated Unit and Integration Test Suite**
  - Path: `backend/account-service/src/test/java/com/fse/banking/account/`
  - Subtasks:
    - `AuthServiceTest`: Test registration, credential check, BCrypt hash verification, concurrent session eviction, logout.
    - `TokenRotationServiceTest`: Test successful refresh rotation, replay attack detection, and complete token family purging on breach.
    - `AccountProvisioningServiceTest`: Test 12-digit number generation, atomic balance master creation, balance precision.
    - `BalanceInquiryServiceTest`: Test cache hit returning `cached=true`, cache miss querying repository and populating Redis with 30s TTL.
    - `KycServiceTest`: Test retrieval of pending profiles, approval transition, and rejection transition.
    - `AuthControllerWebTest` & `AccountControllerWebTest`: MVC slice tests validating endpoint contracts, HTTP status codes, and RFC-7807 responses.
  - Run full Maven build: `mvn clean test` and verify all tests pass with zero failures.
  - _Requirements: REQ-1.1 through REQ-7.3; Design: Section 5_
