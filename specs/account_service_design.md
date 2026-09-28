# Design Specification: Account & Identity Microservice (account-service)

## 1. System Architecture and Component Structure

The Account Service is a Spring Boot 3 microservice responsible for customer onboarding, authentication, session lifecycle, account provisioning, and balance inquiry. It sits alongside the API Gateway and Ledger Engine, connecting directly to the Oracle XE master database and Redis distributed cache.

### System Context Diagram

```mermaid
flowchart TD
    Client["Banking Frontend / Mobile Client"] -->|HTTP / REST| Gateway["API Gateway (:8080)"]
    Gateway -->|"/api/v1/auth/**, /api/v1/accounts/**, /api/v1/kyc/**"| AccSvc["Account Service (:8081)"]
    Gateway -->|"/api/v1/transfers/**, /api/v1/ledger/**"| LedgerSvc["Ledger Mutation Engine (:8082)"]

    AccSvc -->|JDBC / HikariCP| OracleDB[("Oracle XE Master Database (:1521)")]
    AccSvc -->|Lettuce / RESP| RedisCache[("Redis Session & Balance Cache (:6379)")]
    LedgerSvc -->|Mutations & Locks| OracleDB
    LedgerSvc -->|"Invalidates Balance (DEL)"| RedisCache
```

### Component Structure

```mermaid
flowchart TD
    subgraph Controller_Layer["Controller Layer (REST Endpoints)"]
        AC["AuthController\n(/api/v1/auth)"]
        ACC["AccountController\n(/api/v1/accounts)"]
        KC["KycController\n(/api/v1/kyc)"]
        GEH["GlobalExceptionHandler\n(RFC-7807 ProblemDetails)"]
    end

    subgraph Service_Layer["Service & Business Logic Layer"]
        AS["AuthService\n(Login, Register, Logout)"]
        TRS["TokenRotationService\n(RTR, Breach Detection)"]
        APS["AccountProvisioningService\n(12-Digit Gen, Accounts)"]
        BIS["BalanceInquiryService\n(Cache-Aside Pattern)"]
        KS["KycService\n(Verification Queue)"]
    end

    subgraph Adapter_Layer["Infrastructure Adapters & Security"]
        JP["JwtProvider\n(HMAC-SHA256, Claims, JTI)"]
        RS["RedisSessionStore\n(Token Family, Blacklist, Set)"]
        BC["PasswordEncoder\n(BCrypt Strength 10)"]
    end

    subgraph Data_Layer["Data Access Layer (Spring Data JPA)"]
        UR["UserRepository"]
        AR["AccountRepository"]
        BMR["BalanceMasterRepository"]
    end

    AC --> AS
    AC --> TRS
    ACC --> APS
    ACC --> BIS
    KC --> KS

    AS --> JP
    AS --> RS
    AS --> BC
    AS --> UR

    TRS --> RS
    TRS --> JP

    APS --> AR
    APS --> BMR
    APS --> UR

    BIS --> RS
    BIS --> BMR
    BIS --> AR

    KS --> UR
```

## 2. Sequence Flows

### Authentication and Session Creation Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as Client
    participant AuthCtrl as AuthController
    participant AuthSvc as AuthService
    participant UserRepo as UserRepository
    participant Redis as RedisSessionStore
    participant Jwt as JwtProvider

    User->>AuthCtrl: POST /api/v1/auth/login (email, password)
    AuthCtrl->>AuthSvc: authenticate(email, password)
    AuthSvc->>UserRepo: findByEmail(email)
    UserRepo-->>AuthSvc: UserEntity (passwordHash, status, maxSessions)

    alt User locked or inactive
        AuthSvc-->>AuthCtrl: Throw LockedUserException
        AuthCtrl-->>User: 403 Forbidden (Problem Details)
    else Invalid credentials
        AuthSvc->>UserRepo: increment failed_login_attempts
        AuthSvc-->>AuthCtrl: Throw BadCredentialsException
        AuthCtrl-->>User: 401 Unauthorized
    else Valid credentials
        AuthSvc->>UserRepo: reset failed_login_attempts = 0
        AuthSvc->>Redis: countActiveSessions(userId)
        alt activeSessions >= maxConcurrentSessions
            AuthSvc->>Redis: evictOldestSession(userId)
        end
        AuthSvc->>Jwt: generateAccessToken(userId, role, email)
        Jwt-->>AuthSvc: { accessToken, jti, exp }
        AuthSvc->>Redis: registerSessionAndFamily(userId, sessionId, refreshTokenId, jti)
        AuthSvc-->>AuthCtrl: LoginResult (accessToken, refreshTokenId, userInfo)
        AuthCtrl-->>User: 200 OK + Set-Cookie: refresh_token=rt_xxx
    end
```

### Refresh Token Rotation and Breach Detection Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Browser
    participant AuthCtrl as AuthController
    participant TokenSvc as TokenRotationService
    participant Redis as RedisSessionStore
    participant Jwt as JwtProvider

    Client->>AuthCtrl: POST /api/v1/auth/refresh (Cookie: refresh_token=RT-OLD)
    AuthCtrl->>TokenSvc: rotateRefreshToken(tokenValue)
    TokenSvc->>Redis: getRefreshTokenMetadata(tokenValue)

    alt Token not found in Redis
        Redis-->>TokenSvc: null
        TokenSvc-->>AuthCtrl: Throw InvalidTokenException
        AuthCtrl-->>Client: 401 Unauthorized
    else Token marked as REVOKED (Replay Attack)
        Redis-->>TokenSvc: { status: "REVOKED", sessionId: "SESS-101", userId: "USR-01" }
        TokenSvc->>Redis: purgeEntireTokenFamily(sessionId, userId)
        TokenSvc-->>AuthCtrl: Throw TokenBreachException
        AuthCtrl-->>Client: 401 Unauthorized (Breach detected, family wiped)
    else Token marked as ACTIVE
        Redis-->>TokenSvc: { status: "ACTIVE", sessionId: "SESS-101", userId: "USR-01", role: "CUSTOMER" }
        TokenSvc->>Redis: markTokenRevoked(tokenValue)
        TokenSvc->>Jwt: generateAccessToken(userId, role)
        Jwt-->>TokenSvc: newAccessToken
        TokenSvc->>Redis: issueRotatedRefreshToken(sessionId, userId, parentToken=RT-OLD)
        Redis-->>TokenSvc: newRefreshTokenValue
        TokenSvc-->>AuthCtrl: TokenRotationResult(newAccessToken, newRefreshTokenValue)
        AuthCtrl-->>Client: 200 OK (newAccessToken) + Set-Cookie: refresh_token=RT-NEW
    end
```

### Account Provisioning Flow

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin User
    participant AccCtrl as AccountController
    participant ProvSvc as AccountProvisioningService
    participant UserRepo as UserRepository
    participant AccRepo as AccountRepository
    participant BalRepo as BalanceMasterRepository

    Admin->>AccCtrl: POST /api/v1/accounts (userId, accountType, initialDeposit)
    AccCtrl->>ProvSvc: provisionAccount(command)
    ProvSvc->>UserRepo: findById(userId)
    UserRepo-->>ProvSvc: UserEntity

    alt User not found or inactive
        ProvSvc-->>AccCtrl: Throw InvalidUserException
        AccCtrl-->>Admin: 400 Bad Request / 404 Not Found
    else User valid
        Note over ProvSvc: Generate unique 12-digit account number
        Note over ProvSvc: Open @Transactional boundary
        ProvSvc->>AccRepo: save(AccountEntity: ACC-xxx, ACTIVE, type)
        ProvSvc->>BalRepo: save(BalanceMasterEntity: balance=initialDeposit, hold=0, avail=initialDeposit)
        Note over ProvSvc: Commit transaction
        ProvSvc-->>AccCtrl: AccountProvisionResult
        AccCtrl-->>Admin: 201 Created (accountId, accountNumber, initialBalance)
    end
```

### Cached Balance Inquiry Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client as Customer / Teller
    participant AccCtrl as AccountController
    participant BalSvc as BalanceInquiryService
    participant Redis as RedisSessionStore
    participant BalRepo as BalanceMasterRepository

    Client->>AccCtrl: GET /api/v1/accounts/{accountId}/balance
    AccCtrl->>BalSvc: getBalance(accountId)
    BalSvc->>Redis: getCachedBalance("account:balance:" + accountId)

    alt Cache Hit
        Redis-->>BalSvc: JSON cachedBalancePayload
        BalSvc-->>AccCtrl: BalanceResponse (cached = true)
        AccCtrl-->>Client: 200 OK (BalanceResponse, cached=true)
    else Cache Miss
        Redis-->>BalSvc: null
        BalSvc->>BalRepo: findByAccountId(accountId)
        alt Account does not exist
            BalRepo-->>BalSvc: Optional.empty()
            BalSvc-->>AccCtrl: Throw ResourceNotFoundException
            AccCtrl-->>Client: 404 Not Found (RFC-7807)
        else Account found
            BalRepo-->>BalSvc: BalanceMasterEntity
            BalSvc->>Redis: setCachedBalance("account:balance:" + accountId, payload, TTL 30s)
            BalSvc-->>AccCtrl: BalanceResponse (cached = false)
            AccCtrl-->>Client: 200 OK (BalanceResponse, cached=false)
        end
    end
```

## 3. Technology Selection Matrix

| Architectural Layer | Selected Technology | Architectural Rationale |
| :--- | :--- | :--- |
| Framework & Runtime | Java 21 LTS, Spring Boot 3.3.4 | Consistent JVM baseline matching root Maven parent, virtual thread ready, modern security support. |
| Web & REST API | Spring Web MVC, Jakarta Validation | High throughput REST controller baseline with declarative JSR-380 validation. |
| Persistence & ORM | Spring Data JPA, Hibernate 6, HikariCP | Direct binding to Oracle XE master schema with pooled JDBC connection control. |
| Master Database | Oracle Database 21c (ojdbc11) | Canonical enterprise ledger holding users, accounts, and balance master with strict 4-decimal constraints. |
| Caching & Session | Redis 7, Lettuce Driver, Spring Data Redis | Sub-millisecond token blacklisting, token family sets for breach detection, and 30-second balance read-cache. |
| Cryptography & JWT | JJWT (io.jsonwebtoken:jjwt-api:0.12.6), BCrypt | Standard RFC-7519 HMAC-SHA256 signature handling and salted password hashing. |
| Error Representation | RFC-7807 Problem Details | Standardized error contracts across all banking microservices. |
| Automated Testing | JUnit 5, Mockito, H2 in-memory mode | Isolated unit and integration tests executing without live external infrastructure dependencies. |

## 4. Correctness Invariants and Formal Properties

1. Balance Precision Invariant:
   All financial fields (`balance_amount`, `hold_amount`, `available_balance`, `initial_deposit`) must maintain scale equal to 4 and precision up to 18 digits. Floating-point types are strictly forbidden.
   $$\text{scale}(balance) = 4, \quad 0 \le hold\_amount \le balance\_amount, \quad available\_balance = balance\_amount - hold\_amount$$

2. Account Number Invariant:
   Every generated account number must consist of exactly 12 numeric digits and be globally unique across all accounts.
   $$\text{length}(account\_number) = 12, \quad account\_number \in [0-9]^{12}$$

3. Token Family Invariant:
   For any login session $S$, there exists at most one refresh token with status `ACTIVE`. All predecessor tokens in the family have status `REVOKED`.
   $$|\{ t \in \text{Family}(S) \mid \text{status}(t) = \text{ACTIVE} \}| \le 1$$

4. Breach Detection Postcondition:
   If a token $t$ where $\text{status}(t) = \text{REVOKED}$ is submitted for refresh, all keys associated with $\text{Family}(\text{session}(t))$ must be deleted immediately from Redis.
   $$\forall k \in \text{Family}(S), \quad \text{Redis.exists}(k) = \text{false}$$

5. Concurrent Session Bound:
   For any user $U$, the number of active sessions tracked in Redis cannot exceed the user configured maximum.
   $$|\text{ActiveSessions}(U)| \le \text{max\_concurrent\_sessions}(U)$$

## 5. Traceability Matrix

| Requirement ID | Requirement Summary | Design Components Satisfying Requirement |
| :--- | :--- | :--- |
| REQ-1.1 to REQ-1.6 | Customer Registration & Validation | `AuthController`, `AuthService`, `UserEntity`, `UserRepository`, `GlobalExceptionHandler` |
| REQ-2.1 to REQ-2.6 | Login, JWT & Session Limits | `AuthController`, `AuthService`, `JwtProvider`, `RedisSessionStore`, `UserRepository` |
| REQ-3.1 to REQ-3.3 | Refresh Token Rotation & Breach Detection | `TokenRotationService`, `RedisSessionStore`, `AuthController`, `TokenBreachException` |
| REQ-4.1 to REQ-4.3 | Logout & Blacklisting | `AuthService`, `JwtProvider`, `RedisSessionStore`, `AuthController` |
| REQ-5.1 to REQ-5.6 | Account Provisioning & Status Updates | `AccountController`, `AccountProvisioningService`, `AccountEntity`, `BalanceMasterEntity`, `AccountRepository`, `BalanceMasterRepository` |
| REQ-6.1 to REQ-6.4 | Account Listing & Balance Inquiry (Redis Cache) | `AccountController`, `BalanceInquiryService`, `RedisSessionStore`, `BalanceMasterRepository` |
| REQ-7.1 to REQ-7.3 | KYC Review & Approval Queue | `KycController`, `KycService`, `UserRepository`, `UserEntity` |
