# Azure Native Cloud Migration Strategy: Azure SQL & Azure PostgreSQL

This document provides the definitive architectural blueprint and technical execution plan for migrating the omnichannel remittance and fraud screening platform from local Docker Compose to native Microsoft Azure cloud infrastructure.

The target relational architecture uses **Azure SQL Database** for operational master state and **Azure Database for PostgreSQL Flexible Server** for the immutable compliance audit vault.

---

## 1. Relational Architecture Decision: Dual-Cloud Engine Model

The production Azure deployment preserves physical segregation between operational transaction execution and immutable regulatory auditing:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        DUAL-CLOUD RELATIONAL STORAGE MODEL                             │
├────────────────────────────────────────────┬───────────────────────────────────────────┤
│ Master Operational Database                │ Compliance Audit Vault                    │
│ Azure SQL Database (T-SQL)                 │ Azure Database for PostgreSQL (PgSQL)     │
├────────────────────────────────────────────┼───────────────────────────────────────────┤
│ • users                                    │ • ledger_mutation_audit                   │
│ • accounts                                 │ • enforce_audit_immutability() trigger    │
│ • balance_master (UPDLOCK, ROWLOCK)        │ • Append-only enforcement                 │
│ • transactions                             │ • Strict read-only auditor reporting      │
│ • outbox_events (Transactional Outbox)     │ • Physical segregation of duties          │
└────────────────────────────────────────────┴───────────────────────────────────────────┘
```

### Architectural Rationale
1. **Zero Oracle VM Overhead:** Replaces Oracle XE 21c with managed Azure SQL Database. This eliminates the compute limits of Oracle XE (capped at 2 CPU threads, 2 GB RAM, and 12 GB user data), unmanaged Linux VM OS patching, and manual backup maintenance.
2. **Deterministic Pessimistic Concurrency:** Azure SQL Database provides native row-level concurrency via `SELECT ... WITH (UPDLOCK, ROWLOCK)` in `DECIMAL(18, 4)` precision, fully preventing overdrafts and race conditions during high-volume transfers.
3. **Defense-in-Depth Audit Segregation:** By maintaining a dedicated Azure Database for PostgreSQL Flexible Server for `ledger_mutation_audit`, the system enforces a strict physical separation of duties. Even an administrative credential compromise on the operational Azure SQL instance cannot alter compliance audit records protected by PostgreSQL immutability triggers.
4. **Minimal Code Refactoring:** Spring Boot already contains dual-datasource plumbing in `ledger-mutation-engine`. The master configuration is transitioned from Oracle to SQL Server, while the PostgreSQL configuration is retained and pointed to Azure Database for PostgreSQL with SSL.

---

## 2. Complete Workload & Service Mapping Matrix

| Layer / Role | Local Development (Docker Compose) | Azure Native Cloud Resource | Architectural Configuration & Protocol |
| :--- | :--- | :--- | :--- |
| **Presentation Tier** | Flutter Web & Mobile / React SPA (:3000) | **Azure Static Web Apps (SWA)** & Azure CDN | Global edge distribution, HTTPS termination, zero web server maintenance |
| **Edge Perimeter & WAF** | Local port mapping to `:8080` | **Azure Application Gateway v2 (WAF_v2)** | Ingress via AGIC, OWASP CRS 3.2 protection, SSL offloading on port 443 |
| **Perimeter Routing** | Spring Cloud Gateway (`gateway-service` :8080) | **AKS Deployment (`gateway-service`)** | Internal cluster service, Redis token-bucket rate limiting (10 rps), JWT validation |
| **Identity & KYC** | Spring Boot (`account-service` :8081) | **AKS Deployment (`account-service`)** | 2 to 6 replicas, short-lived JWT generation, Refresh Token Rotation (RTR) |
| **Remittance Core** | Spring Boot (`ledger-mutation-engine` :8082) | **AKS Deployment (`ledger-mutation-engine`)** | 2 to 8 replicas, row locks, outbox pattern, T24 format conversion |
| **Fraud Risk Engine** | FastAPI / Python (`risk-service` :8084) | **AKS Deployment (`risk-service`)** | Compute-optimized node pool (F-series or D-series), ONNX INT8 Qwen2.5-0.5B inference, p99 < 200 ms SLA |
| **Mainframe Seam** | Local TCP loopback listener (`temenos-t24-cbs` :9100) | **AKS Internal Service / Dedicated Integration Subnet** | Isolated internal namespace container simulating Temenos T24 OFSCore responses |
| **Notifications** | Spring Boot (`notification-service` :8083) | **AKS Deployment (`notification-service`)** | KEDA autoscaler driven by Azure Event Hubs topic consumer lag |
| **Master Database** | Oracle Database XE 21c (`XEPDB1` :1521) | **Azure SQL Database (General Purpose or Business Critical)** | `DECIMAL(18, 4)` precision, `SELECT ... WITH (UPDLOCK, ROWLOCK)`, automated backups |
| **Audit Vault** | PostgreSQL 16 (`banking_audit` :5433) | **Azure Database for PostgreSQL Flexible Server** | Immutable audit table, native PL/pgSQL trigger `enforce_audit_immutability()` |
| **In-Memory Cache** | Redis 7.2-alpine (`redis-cache` :6379) | **Azure Cache for Redis (Standard C1)** | Primary/replica failover, TLS port 6380, VNet private endpoint |
| **Event Bus** | Apache Kafka 3.7.0 (KRaft :9092) | **Azure Event Hubs (Standard Tier)** | Kafka 1.0+ API compatible on port 9093, auto-inflate, SASL_SSL authentication |
| **SMTP Delivery** | MailHog mock server (:1025 / :8025) | **Azure Communication Services (Email)** | Authenticated transactional email dispatch for customer receipts and 2FA OTPs |
| **Secrets Management** | Docker Compose environment variables | **Azure Key Vault + Azure Workload Identity** | CSI driver secret injection, managed identities, zero hardcoded passwords |
| **Telemetry & APM** | Local Datadog Agent container (:8126 / :4318) | **Datadog Agent AKS DaemonSet** or **Azure Monitor & Managed Prometheus** | W3C trace propagation (`traceparent`), container metrics, OTLP ingestion |
| **CI/CD Pipeline** | Local manual builds / scripts | **GitHub Actions + Azure Container Registry (ACR)** | OIDC federated login, automated maven/pytest, Trivy scanning, Helm cluster deployment |

---

## 3. Cloud Network Architecture

All cloud resources are deployed within a hardened Azure Virtual Network (VNet) topology with strict Network Security Groups (NSGs) and Private Endpoints.

```
                                  [ Internet / Mobile & Web Clients ]
                                                   │
                                                   │ HTTPS (:443)
                                                   ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Azure Virtual Network: vnet-banking-prod (10.0.0.0/16)                                                  │
│                                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ Subnet: snet-appgw (10.0.1.0/24)                                                                  │  │
│  │ └─ Azure Application Gateway v2 (WAF_v2, SSL Termination, OWASP CRS 3.2)                          │  │
│  └──────────────────────────────────────────────────┬────────────────────────────────────────────────┘  │
│                                                     │ Private Cluster Routing (AGIC)                    │
│                                                     ▼                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ Subnet: snet-aks-nodes (10.0.2.0/23)                                                              │  │
│  │ ┌───────────────────────────────────────────────────────────────────────────────────────────────┐ │  │
│  │ │ Azure Kubernetes Service (AKS Cluster)                                                        │ │  │
│  │ │                                                                                               │ │  │
│  │ │  [gateway-service] ───► [account-service]                                                     │ │  │
│  │ │         │                      │                                                              │ │  │
│  │ │         ▼                      ▼ (TLS 6380)                                                   │ │  │
│  │ │  [ledger-engine]        [Azure Cache for Redis]                                               │ │  │
│  │ │    │          │                                                                               │ │  │
│  │ │    │ (HTTP)   └───────► [notification-service] ──► [Azure Communication Services]            │ │  │
│  │ │    ▼                          │                                                               │ │  │
│  │ │  [risk-service]               │ (Kafka :9093)                                                 │ │  │
│  │ │                               ▼                                                               │ │  │
│  │ │                      [Azure Event Hubs]                                                       │ │  │
│  │ └───────────────────────────────┬───────────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────┼─────────────────────────────────────────────────────────────────┘  │
│                                    │ Private Endpoints                                                  │
│                                    ▼                                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ Subnet: snet-private-endpoints (10.0.4.0/24)                                                      │  │
│  │ ├─ Private Endpoint: Azure SQL Database (Master State, Port 1433)                                 │  │
│  │ ├─ Private Endpoint: Azure Database for PostgreSQL (Audit Vault, Port 5432)                       │  │
│  │ ├─ Private Endpoint: Azure Cache for Redis (Port 6380)                                            │  │
│  │ ├─ Private Endpoint: Azure Event Hubs Namespace (Port 9093)                                       │  │
│  │ └─ Private Endpoint: Azure Key Vault (Port 443)                                                   │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Database Implementation & Schemas

### A. Azure SQL Database: Master Operational State
Azure SQL Database replaces Oracle XE 21c. All operational entities live here.

```sql
-- ==============================================================================
-- 1. Table: users
-- ==============================================================================
CREATE TABLE users (
    user_id                 NVARCHAR(64) NOT NULL PRIMARY KEY,
    first_name              NVARCHAR(100) NOT NULL,
    middle_name             NVARCHAR(100) NULL,
    last_name               NVARCHAR(100) NOT NULL,
    email                   NVARCHAR(255) NOT NULL UNIQUE,
    phone_number            NVARCHAR(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           NVARCHAR(100) NOT NULL,
    role                    NVARCHAR(20) NOT NULL,
    password_hash           NVARCHAR(255) NOT NULL,
    pin_hash                NVARCHAR(255) NULL,
    max_concurrent_sessions SMALLINT DEFAULT 3 NOT NULL,
    failed_login_attempts   SMALLINT DEFAULT 0 NOT NULL,
    status                  NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at              DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at              DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT chk_usr_role CHECK (role IN ('CUSTOMER', 'TELLER', 'MANAGER', 'ADMIN')),
    CONSTRAINT chk_usr_status CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED'))
);

-- ==============================================================================
-- 2. Table: accounts
-- ==============================================================================
CREATE TABLE accounts (
    account_id     NVARCHAR(64) NOT NULL PRIMARY KEY,
    user_id        NVARCHAR(64) NOT NULL,
    account_number NVARCHAR(32) NOT NULL UNIQUE,
    account_type   NVARCHAR(20) NOT NULL,
    status         NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    credit_limit   DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at     DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at     DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS', 'CHECKING')),
    CONSTRAINT chk_acc_status CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL')),
    CONSTRAINT chk_acc_credit_limit CHECK (credit_limit >= 0)
);

-- ==============================================================================
-- 3. Table: balance_master (Strict Mathematical Sanity Checks)
-- ==============================================================================
CREATE TABLE balance_master (
    account_id        NVARCHAR(64) NOT NULL PRIMARY KEY,
    balance_amount    DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    hold_amount       DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    available_balance DECIMAL(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_bm_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_bm_positive_balance CHECK (balance_amount >= 0),
    CONSTRAINT chk_bm_positive_hold CHECK (hold_amount >= 0),
    CONSTRAINT chk_bm_available_balance CHECK (balance_amount >= hold_amount)
);

-- ==============================================================================
-- 4. Table: transactions
-- ==============================================================================
CREATE TABLE transactions (
    transaction_id         NVARCHAR(64) NOT NULL PRIMARY KEY,
    source_account_id      NVARCHAR(64) NOT NULL,
    target_account_id      NVARCHAR(64) NOT NULL,
    amount                 DECIMAL(18, 4) NOT NULL,
    currency               NVARCHAR(3) DEFAULT 'PHP' NOT NULL,
    transaction_type       NVARCHAR(20) NOT NULL,
    status                 NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    requires_maker_checker BIT DEFAULT 0 NOT NULL,
    approved_by            NVARCHAR(64) NULL,
    memo                   NVARCHAR(255) NULL,
    created_at             DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    updated_at             DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    CONSTRAINT fk_tx_source FOREIGN KEY (source_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_target FOREIGN KEY (target_account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_tx_amount CHECK (amount > 0)
);

-- ==============================================================================
-- 5. Table: outbox_events (Transactional Outbox Pattern)
-- ==============================================================================
CREATE TABLE outbox_events (
    event_id        NVARCHAR(64) NOT NULL PRIMARY KEY,
    aggregate_type  NVARCHAR(64) NOT NULL,
    aggregate_id    NVARCHAR(64) NOT NULL,
    event_type      NVARCHAR(64) NOT NULL,
    payload         NVARCHAR(MAX) NOT NULL,
    status          NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    retry_count     INT DEFAULT 0 NOT NULL,
    created_at      DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    processed_at    DATETIMEOFFSET NULL
);

-- ==============================================================================
-- 6. Table: notifications
-- ==============================================================================
CREATE TABLE notifications (
    notification_id   NVARCHAR(64) NOT NULL PRIMARY KEY,
    user_id           NVARCHAR(64) NOT NULL,
    recipient_address NVARCHAR(255) NOT NULL,
    notification_type NVARCHAR(30) NOT NULL,
    channel           NVARCHAR(20) DEFAULT 'EMAIL' NOT NULL,
    subject           NVARCHAR(255) NOT NULL,
    content_payload   NVARCHAR(MAX) NOT NULL,
    dispatch_status   NVARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    delivery_attempts INT DEFAULT 0 NOT NULL,
    created_at        DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET() NOT NULL,
    dispatched_at     DATETIMEOFFSET NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

### B. Azure Database for PostgreSQL: Compliance Audit Vault
Azure Database for PostgreSQL Flexible Server hosts the immutable audit journal.

```sql
-- ============================================================
-- Azure Database for PostgreSQL Flexible Server
-- Compliance Audit Vault (banking_audit)
-- ============================================================

CREATE TABLE IF NOT EXISTS ledger_mutation_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    transaction_id VARCHAR(64) NOT NULL UNIQUE,
    account_id VARCHAR(36) NOT NULL,
    mutation_type VARCHAR(16) NOT NULL,
    mutation_amount NUMERIC(18,4) NOT NULL,
    before_balance NUMERIC(18,4) NOT NULL,
    after_balance NUMERIC(18,4) NOT NULL,
    initiator_user_id VARCHAR(36) NOT NULL,
    approved_by_user_id VARCHAR(36),
    status VARCHAR(20) NOT NULL DEFAULT 'COMMITTED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ledger_mutation_audit_mutation_amount_check CHECK (mutation_amount > 0),
    CONSTRAINT ledger_mutation_audit_after_balance_check CHECK (after_balance >= 0),
    CONSTRAINT ledger_mutation_audit_mutation_type_check CHECK (mutation_type IN ('TRANSFER', 'DEBIT', 'CREDIT', 'HOLD', 'RELEASE')),
    CONSTRAINT ledger_mutation_audit_status_check CHECK (status IN ('COMMITTED', 'FAILED', 'ROLLED_BACK'))
);

CREATE INDEX IF NOT EXISTS idx_audit_tx_id ON ledger_mutation_audit(transaction_id);
CREATE INDEX IF NOT EXISTS idx_audit_acc_time ON ledger_mutation_audit(account_id, created_at DESC);

-- Native Anti-Tamper Immutability Function
CREATE OR REPLACE FUNCTION enforce_audit_immutability()
RETURNS TRIGGER AS
$$
BEGIN
    RAISE EXCEPTION 'Compliance Violation: ledger_mutation_audit is strictly append-only. UPDATE and DELETE operations are blocked.';
END;
$$ LANGUAGE plpgsql;

-- Native Anti-Tamper Trigger
DROP TRIGGER IF EXISTS trg_immutable_audit ON ledger_mutation_audit;
CREATE TRIGGER trg_immutable_audit
    BEFORE UPDATE OR DELETE
ON ledger_mutation_audit
FOR EACH ROW
EXECUTE FUNCTION enforce_audit_immutability();
```

---

## 5. Application Code & Configuration Changes

### 1. Root Maven Dependencies (`backend/pom.xml`)
Add the Microsoft SQL Server JDBC driver alongside the existing PostgreSQL driver:

```xml
<dependencies>
    <!-- Microsoft SQL Server JDBC Driver (For Azure SQL) -->
    <dependency>
        <groupId>com.microsoft.sqlserver</groupId>
        <artifactId>mssql-jdbc</artifactId>
        <version>12.6.1.jre11</version>
    </dependency>

    <!-- PostgreSQL JDBC Driver (Retained for Azure Database for PostgreSQL) -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <version>${postgresql.version}</version>
    </dependency>
</dependencies>
```

### 2. Dual-Datasource Configuration in `ledger-mutation-engine`
Update `backend/ledger-mutation-engine/src/main/resources/application.properties` (or provide profile `application-azure.properties`):

```properties
# =========================================================================
# 1. PRIMARY DATASOURCE: AZURE SQL DATABASE (Master Relational State)
# =========================================================================
spring.datasource.master.url=jdbc:sqlserver://sql-banking-master.database.windows.net:1433;databaseName=sqldb-master;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;
spring.datasource.master.username=${AZURE_SQL_USERNAME}
spring.datasource.master.password=${AZURE_SQL_PASSWORD}
spring.datasource.master.driver-class-name=com.microsoft.sqlserver.jdbc.SQLServerDriver
spring.datasource.master.hikari.pool-name=HikariPool-AzureSqlMaster
spring.datasource.master.hikari.maximum-pool-size=30
spring.datasource.master.hikari.minimum-idle=5
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.SQLServerDialect

# =========================================================================
# 2. SECONDARY DATASOURCE: AZURE DATABASE FOR POSTGRESQL (Audit Vault)
# =========================================================================
spring.datasource.postgres.url=jdbc:postgresql://psql-banking-audit.postgres.database.azure.com:5432/banking_audit?sslmode=require
spring.datasource.postgres.username=${AZURE_POSTGRES_USERNAME}
spring.datasource.postgres.password=${AZURE_POSTGRES_PASSWORD}
spring.datasource.postgres.driver-class-name=org.postgresql.Driver
spring.datasource.postgres.hikari.pool-name=HikariPool-AzurePostgresAudit
spring.datasource.postgres.hikari.maximum-pool-size=30
spring.datasource.postgres.hikari.minimum-idle=5
```

### 3. Java Master Datasource Class
Create `AzureSqlMasterDataSourceConfig.java` to replace `OracleMasterDataSourceConfig.java`:

```java
package com.bank.ledger.engine.config;

import com.zaxxer.hikari.HikariDataSource;
import jakarta.persistence.EntityManagerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(
    basePackages = "com.bank.ledger.engine.repository.master",
    entityManagerFactoryRef = "masterEntityManagerFactory",
    transactionManagerRef = "masterTransactionManager"
)
public class AzureSqlMasterDataSourceConfig {

    @Primary
    @Bean
    @ConfigurationProperties("spring.datasource.master")
    public DataSourceProperties masterDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Primary
    @Bean(name = "masterDataSource")
    @ConfigurationProperties("spring.datasource.master.hikari")
    public DataSource masterDataSource() {
        return masterDataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Primary
    @Bean(name = "masterEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean masterEntityManagerFactory(
            EntityManagerFactoryBuilder builder,
            @Qualifier("masterDataSource") DataSource dataSource) {

        Map<String, Object> properties = new HashMap<>();
        properties.put("hibernate.dialect", "org.hibernate.dialect.SQLServerDialect");
        properties.put("hibernate.hbm2ddl.auto", "none");

        return builder
                .dataSource(dataSource)
                .packages("com.bank.ledger.engine.entity.master")
                .persistenceUnit("azureSqlMasterUnit")
                .properties(properties)
                .build();
    }

    @Primary
    @Bean(name = "masterTransactionManager")
    public PlatformTransactionManager masterTransactionManager(
            @Qualifier("masterEntityManagerFactory") EntityManagerFactory entityManagerFactory) {
        return new JpaTransactionManager(entityManagerFactory);
    }
}
```

The secondary configuration class `PostgresAuditDataSourceConfig.java` remains unchanged in functionality, continuing to manage the `postgresTransactionManager` and audit entity package.

---

## 6. Event Streaming and Caching Migration

### Azure Event Hubs (Kafka Head)
1. **Namespace Setup:** Deploy Event Hubs Standard namespace `evh-banking-prod`.
2. **Configuration:**
   ```properties
   spring.kafka.bootstrap-servers=evh-banking-prod.servicebus.windows.net:9093
   spring.kafka.properties.security.protocol=SASL_SSL
   spring.kafka.properties.sasl.mechanism=PLAIN
   spring.kafka.properties.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
       username="$ConnectionString" \
       password="${EVENT_HUBS_CONNECTION_STRING}";
   spring.kafka.consumer.group-id=notification-workers
   spring.kafka.producer.acks=all
   spring.kafka.producer.retries=3
   ```
   No changes are required in `KafkaEventPublisher.java` or `OutboxRelayScheduler.java`.

### Azure Cache for Redis
1. **Instance Setup:** Deploy `redis-banking-prod` (Standard C1 tier).
2. **Configuration:**
   ```properties
   spring.data.redis.host=redis-banking-prod.redis.cache.windows.net
   spring.data.redis.port=6380
   spring.data.redis.ssl.enabled=true
   spring.data.redis.password=${REDIS_AUTH_KEY}
   spring.data.redis.timeout=3000
   ```
   All six namespaces (`blacklist:jti:*`, `refresh_token:*`, `token_family:*`, `auth:user-sessions:*`, `otp:*`, `account:balance:*`) function with sub-5ms latency.

---

## 7. AKS Cluster & Pod Deployment Strategy

### Node Pool Allocation
1. **System Pool (`systempool`):** `Standard_D2s_v5` (2-3 nodes) for CoreDNS, AGIC Ingress, Datadog DaemonSet.
2. **User Pool (`userpool`):** `Standard_D4s_v5` (2-8 nodes) for Spring Boot microservices (`gateway`, `account`, `ledger`, `notification`).
3. **Risk Engine Pool (`riskpool`):** Compute-optimized nodes (`Standard_F4s_v2` or `Standard_F8s_v2`) for `risk-service` running ONNX INT8 Qwen2.5-0.5B inference with `ONNX_INTRA_OP_THREADS=8` to guarantee p99 < 200 ms SLA under load.

### Scaling Mechanics
- **Horizontal Pod Autoscalers (HPA):** Gateway, Account, Ledger, and Risk pods scale on CPU (>70%) and request rate.
- **KEDA (Kubernetes Event-driven Autoscaling):** Notification pods scale dynamically based on Azure Event Hubs topic consumer lag.

---

## 8. Verification of Chaos Engineering Protocols

| Chaos Protocol | Local Testing Method | Azure Native Testing Method & Defense | Expected System Defense & SLA |
| :--- | :--- | :--- | :--- |
| **1. Database Degradation** | Throttling Oracle XE container latency or connection pool. | Inject latency or choke DTU/vCore on Azure SQL Database. | Resilience4j circuit breaker on API Gateway / Orchestrator trips open. Client receives balance from Azure Cache for Redis within 20 ms with header `cached: true`. |
| **2. Risk Engine Interruption** | Running `docker stop risk-service`. | Delete `risk-service` pod via `kubectl delete pod -l app=risk-service`. | Spring Boot Orchestrator detects connection loss within the ≤ 200 ms SLA timeout, trips its fallback handler, and cleanly aborts the transfer with HTTP 503 / 422. Master balances in Azure SQL remain untouched (zero partial commits). |
| **3. Perimeter Rejection Check** | Direct curl attacks against internal ports (`:8081`, `:8082`, `:8084`, `:1433`, `:5432`). | Penetration script fired against cluster public IP and private endpoints from outside the VNet. | Application Gateway and Kubernetes Network Policies block all direct traffic. Inbound connections directly to internal service ports receive connection refusal or drop, proving all traffic must transit Gateway port 8080. |
