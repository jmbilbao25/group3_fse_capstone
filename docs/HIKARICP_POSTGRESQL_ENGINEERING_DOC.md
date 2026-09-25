# Technical Architecture & Engineering Documentation
## Module: High-Throughput HikariCP Connection Pool Isolation (PostgreSQL 15+)
**Project:** Core Retail Ledger & Balance Mutation Engine (FSE Capstone - Group 3)  
**Author/Owner:** Romzel Madi (Backend / Database Infrastructure Lead)  
**Milestone:** Day 32 - Database Infrastructure & Multi-Datasource Pool Isolation  
**Target Engine:** `ledger-mutation-engine`  
**Database:** PostgreSQL 15-alpine (Immutable Audit Store)  

---

## 1. Executive Summary & Problem Statement

In an enterprise banking architecture processing high-frequency balance mutations (Funds Transfers), maintaining **high throughput** while guaranteeing **zero data corruption** requires decoupling the master transactional ledger from the compliance audit trail.

### The Architectural Problem:
If both Oracle (Live Transaction State) and PostgreSQL (Immutable Audit Trail) share a single global connection pool or uncalibrated connection pools:
1. **Thread Starvation Risk:** Heavy reporting or long audit writes on PostgreSQL could exhaust database threads, cascading into failure for Oracle’s real-time balance mutation locks.
2. **Connection Leak Cascades:** Unmonitored TCP sockets can lead to uncollected connections and system out-of-memory (OOM) failures under burst traffic.
3. **Improper Multi-Tenancy:** Default Spring Boot auto-configuration attempts to bind a single primary datasource, which causes ambiguous dependency injection failures when orchestrating dual databases.

### The Solution:
We implemented **Strict HikariCP Connection Pool Isolation** (`HikariPool-PostgresAudit`) with dedicated Spring `@Configuration`, custom `LocalContainerEntityManagerFactoryBean`, dedicated `JpaTransactionManager`, and strict pool dimensions (`max=30`, `min=5`, `timeout=20s`).

---

## 2. Pool Sizing & Sizing Math Justification

Connection pool dimensions are not arbitrary numbers. They are engineered based on PostgreSQL’s process-based architecture and hardware utilization limits:

$$\text{Optimal Pool Size} = 2 \times \text{CPU Cores} + \text{Disk Spindle / Effective Concurrency}$$

For a high-concurrency mutation engine handling transfer spikes:

| Metric | Configured Value | Engineering Rationale |
| :--- | :--- | :--- |
| **`pool-name`** | `HikariPool-PostgresAudit` | Unique pool identity for JMX monitoring, APM agents (Datadog/Prometheus), and log forensics. |
| **`maximum-pool-size`** | `30` | Hard ceiling preventing connection storming on PostgreSQL, keeping query response latencies sub-millisecond without database context-switch thrashing. |
| **`minimum-idle`** | `5` | Pool pre-warming floor. Guarantees 5 connections are held open in memory at all times, eliminating TCP 3-way handshake and TLS negotiation overhead for incoming transfers. |
| **`connection-timeout`** | `20,000 ms` (20s) | Fail-fast threshold. If all 30 connections are saturated, incoming requests wait at most 20 seconds before fast-failing, preventing infinite HTTP thread hanging. |
| **`idle-timeout`** | `300,000 ms` (5 min) | Gracefully retires burst connections above the idle floor (5) that have been inactive for 5 minutes. |
| **`max-lifetime`** | `1,200,000 ms` (20 min) | Automatically recycles connections every 20 minutes to prevent database-side memory fragmentation and stale state. |
| **`auto-commit`** | `false` | Critical financial integrity requirement. Disables automatic commits so mutations are governed strictly by Spring’s `@Transactional` boundaries. |

---

## 3. Configuration & Component Architecture

```
[ Incoming Funds Transfer Request ]
                │
                ▼
   ledger-mutation-engine
   ┌──────────────────────────────────────────────┐
   │  PostgresAuditDataSourceConfig               │
   │  ├── HikariDataSource ("HikariPool-PostgresAudit")
   │  │   ├── Max Pool: 30                        │
   │  │   └── Min Idle: 5                         │
   │  ├── LocalContainerEntityManagerFactoryBean  │
   │  │   └── Scans: com.bank.ledger.engine.entity.audit
   │  └── JpaTransactionManager ("postgresTransactionManager")
   └──────────────────────┬───────────────────────┘
                          │ (TCP Port 5433 -> 5432)
                          ▼
            Docker: banking-postgres-db (PostgreSQL 15)
            └── Database: ledger_audit_db
                └── Table: ledger_mutation_audit
```

### 3.1 Properties Configuration (`application.properties`)
```properties
# SECONDARY DATASOURCE: POSTGRESQL 15+ (Immutable Audit Trail)
spring.datasource.postgres.url=jdbc:postgresql://localhost:5433/ledger_audit_db
spring.datasource.postgres.jdbc-url=jdbc:postgresql://localhost:5433/ledger_audit_db
spring.datasource.postgres.username=postgres
spring.datasource.postgres.password=postgres
spring.datasource.postgres.driver-class-name=org.postgresql.Driver

# HikariCP Pool Isolation for PostgreSQL
spring.datasource.postgres.hikari.pool-name=HikariPool-PostgresAudit
spring.datasource.postgres.hikari.maximum-pool-size=30
spring.datasource.postgres.hikari.minimum-idle=5
spring.datasource.postgres.hikari.connection-timeout=20000
spring.datasource.postgres.hikari.idle-timeout=300000
spring.datasource.postgres.hikari.max-lifetime=1200000
spring.datasource.postgres.hikari.auto-commit=false
```

> **Note on Port Isolation:**  
> Windows host port `5433` is routed to container port `5432` in `docker-compose.yml` to prevent binding conflicts with any host PostgreSQL service running on `5432`.

---

## 4. Implementation Codebase

### 4.1 Configuration Class: `PostgresAuditDataSourceConfig.java`
Isolates Spring Data JPA repositories and entity scanning:

```java
@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(
    basePackages = "com.bank.ledger.engine.repository.audit",
    entityManagerFactoryRef = "postgresEntityManagerFactory",
    transactionManagerRef = "postgresTransactionManager"
)
public class PostgresAuditDataSourceConfig {

    @Bean
    @ConfigurationProperties("spring.datasource.postgres")
    public DataSourceProperties postgresDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean(name = "postgresAuditDataSource")
    @ConfigurationProperties("spring.datasource.postgres.hikari")
    public DataSource postgresAuditDataSource() {
        return postgresDataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Bean(name = "postgresEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean postgresEntityManagerFactory(
            EntityManagerFactoryBuilder builder,
            @Qualifier("postgresAuditDataSource") DataSource dataSource) {

        Map<String, Object> properties = new HashMap<>();
        properties.put("hibernate.hbm2ddl.auto", "none");

        return builder
                .dataSource(dataSource)
                .packages("com.bank.ledger.engine.entity.audit")
                .persistenceUnit("postgresAuditUnit")
                .properties(properties)
                .build();
    }

    @Bean(name = "postgresTransactionManager")
    public PlatformTransactionManager postgresTransactionManager(
            @Qualifier("postgresEntityManagerFactory") EntityManagerFactory entityManagerFactory) {
        return new JpaTransactionManager(entityManagerFactory);
    }
}
```

### 4.2 Immutable Audit Entity: `LedgerMutationAudit.java`
Uses fixed-point `BigDecimal` for zero-loss financial precision matching PostgreSQL's `NUMERIC(18, 4)`:

```java
@Entity
@Table(name = "ledger_mutation_audit")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LedgerMutationAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "audit_id")
    private Long auditId;

    @Column(name = "transaction_id", nullable = false, length = 64)
    private String transactionId;

    @Column(name = "account_id", nullable = false, length = 36)
    private String accountId;

    @Column(name = "mutation_type", nullable = false, length = 16)
    private String mutationType; // 'TRANSFER'

    @Column(name = "mutation_amount", nullable = false, precision = 18, scale = 4)
    private BigDecimal mutationAmount;

    @Column(name = "before_balance", nullable = false, precision = 18, scale = 4)
    private BigDecimal beforeBalance;

    @Column(name = "after_balance", nullable = false, precision = 18, scale = 4)
    private BigDecimal afterBalance;

    @Column(name = "initiator_user_id", nullable = false, length = 36)
    private String initiatorUserId;

    @Column(name = "approved_by_user_id", length = 36)
    private String approvedByUserId;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
```

---

## 5. Verification & Validation Evidence

### 5.1 Automated Integration Test: `PostgresHikariTest.java`
Tests verify both pool dimensions via reflection/getters and end-to-end audit write/read:

```powershell
.\mvnw.cmd test -Dtest=PostgresHikariTest -pl ledger-mutation-engine
```

### 5.2 Test Output Logs:
```text
DEBUG ... HikariConfig : poolName........................"HikariPool-PostgresAudit"
DEBUG ... HikariConfig : maximumPoolSize.................30
DEBUG ... HikariConfig : minimumIdle.....................5
DEBUG ... HikariConfig : connectionTimeout...............20000
INFO  ... HikariDataSource : HikariPool-PostgresAudit - Starting...
INFO  ... HikariPool       : HikariPool-PostgresAudit - Added connection org.postgresql.jdbc.PgConnection@5fc1e4fb
INFO  ... HikariDataSource : HikariPool-PostgresAudit - Start completed.
DEBUG ... HikariPool       : HikariPool-PostgresAudit - After adding stats (total=5, active=0, idle=5, waiting=0)

==========================================================
>>> HIKARICP POOL VERIFICATION <<<
Pool Name:          HikariPool-PostgresAudit
Maximum Pool Size:  30
Minimum Idle:       5
Connection Timeout: 20000 ms
==========================================================
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

### 5.3 Live Container Database Evidence:
Query executed directly on `banking-postgres-db`:
```bash
docker exec -it banking-postgres-db psql -U postgres -d ledger_audit_db -c "SELECT audit_id, transaction_id, mutation_type, mutation_amount, before_balance, after_balance, status FROM ledger_mutation_audit ORDER BY audit_id DESC LIMIT 3;"
```
Output:
```text
 audit_id |    transaction_id     | mutation_type | mutation_amount | before_balance | after_balance |  status   
----------+-----------------------+---------------+-----------------+----------------+---------------+-----------
        2 | TEST-TX-1790151544106 | TRANSFER      |       1500.0000 |     10000.0000 |     8500.0000 | COMMITTED
        1 | T5001                 | TRANSFER      |       2000.0000 |    300000.0000 |   298000.0000 | COMMITTED
```

---

## 6. How to Run & Validate in Any Environment

1. **Spin up PostgreSQL via Docker Compose:**
   ```bash
   docker compose up -d postgres-db
   ```
2. **Execute HikariCP Pool & Integration Verification:**
   ```powershell
   .\mvnw.cmd test -Dtest=PostgresHikariTest -pl ledger-mutation-engine
   ```
3. **Inspect Active Hikari Pool Health:**
   Check application logs for `HikariPool-PostgresAudit` stats.
