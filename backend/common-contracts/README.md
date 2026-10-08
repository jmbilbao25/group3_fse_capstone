# Common Contracts Library

Shared Java domain models, transfer schemas, Kafka event contracts, domain enums, and exception types for the banking platform.

## 1. Overview and purpose

`common-contracts` is a shared library module consumed by all Spring Boot microservices in the backend repository. It guarantees binary schema compatibility across inter-service REST calls, Kafka event serialization, and database interaction boundaries.

## 2. Tech stack

* Runtime: Java 21 LTS
* Serialization: Jackson 2.x (`jackson-databind`, `jackson-datatype-jsr310`)
* Validation: Jakarta Validation API 3.x (JSR-380)
* Boilerplate reduction: Project Lombok
* Build tool: Apache Maven 3.9+ (packaged as JAR dependency)

## 3. Package layout and scope

```
com.bank.ledger.contracts/
├── dto/
│   ├── BalanceMutationRequest.java
│   ├── BalanceMutationResponse.java
│   ├── LedgerEventPayload.java
│   ├── T24FundsTransferRequest.java
│   ├── T24FundsTransferResponse.java
│   ├── T24ReversalRequest.java
│   └── T24ReversalResponse.java
└── enums/
    ├── EventType.java
    ├── MutationType.java
    ├── TransactionStatus.java
    └── Currency.java

com.fse.banking.common/
├── dto/
│   ├── ApiResponse.java
│   ├── ErrorResponse.java
│   └── PageResponse.java
├── enums/
│   ├── AccountStatus.java
│   ├── UserRole.java
│   └── KycTier.java
└── exception/
    ├── AccountFrozenException.java
    ├── DuplicateTransactionException.java
    ├── InsufficientBalanceException.java
    └── TransactionLimitExceededException.java
```

## 4. Key contracts and usage

### Kafka event contracts
* `LedgerEventPayload`: Canonical schema emitted to the `ledger.mutations` and `account.events` topics whenever a balance state change commits.
* `EventType`: Defines event kinds: `TRANSFER_INITIATED`, `MUTATION_COMMITTED`, `MUTATION_FAILED`, `ADVISORY_TRIGGERED`, `STEP_UP_REQUIRED`.

### T24 Core Banking Integration DTOs
* `T24FundsTransferRequest` and `T24FundsTransferResponse`: Mirror the Temenos T24 core banking payload structure for outbound funds settlement.
* `T24ReversalRequest` and `T24ReversalResponse`: Provide compensating reversal contracts for failed interbank transfers.

## 5. Critical rules for AI agents

1. Binary backward compatibility: Never remove or rename fields in serialized DTOs without providing backward-compatible Jackson aliases (`@JsonProperty`, `@JsonAlias`).
2. Enum stability: Enums such as `MutationType` and `EventType` are stored as string values in database columns and Kafka event payloads. Never reorder or alter existing string values.
3. Keep dependencies lean: This module must remain free of Spring Web, Spring Data, or heavyweight framework dependencies. It should contain only POJOs, records, enums, validation annotations, and serialization directives.
4. Clean exception hierarchy: Business exceptions extending `BankingException` must carry unique error codes and client-safe default messages.

## 6. Build and local installation

To compile and install into your local Maven cache:

```bash
cd backend/common-contracts
mvn clean install
```
