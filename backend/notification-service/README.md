# Notification and Alert Service

Real-time WebSocket alerts, email receipts, and out-of-band security event dispatching service for the banking platform.

## 1. Overview and purpose

The Notification Service delivers asynchronous transaction notifications, security alerts, and receipts to customers. It consumes financial mutation events and fraud risk triggers from Apache Kafka, formats messages via templates, and dispatches them across real-time WebSockets, HTML emails, and SMS delivery adapters.

It runs on port 8083, routed through `gateway-service` on port 8080.

## 2. Tech stack

* Runtime: Java 21 LTS
* Framework: Spring Boot 3.3.x, Spring WebSocket (STOMP message broker)
* Event consumer: Spring for Apache Kafka (`ledger.mutations`, `risk.events`)
* Templating: Thymeleaf for structured HTML transaction receipts and security advisories
* Mail transport: Spring Mail / JavaMailSender
* Caching: Redis 7 (notification deduplication and rate limits)
* Distributed tracing: OpenTelemetry with W3C Trace Context propagation
* Build tool: Apache Maven 3.9+

## 3. Scope and boundaries

### In scope
* Consuming committed financial mutations from Kafka topics.
* Delivering real-time in-app balance updates over STOMP WebSocket channels (`/ws/**`).
* Generating and dispatching HTML transaction receipts with unique reference numbers.
* Dispatching high-priority security alerts when advisory warnings or step-up authentication are triggered.
* Mock adapters for SMS and external gateway dispatching.

### Out of scope
* Transaction authorization codes via SMS: Strictly prohibited by policy.
* Ledger mutation logic: Handled by `ledger-mutation-engine`.
* Fraud risk scoring: Handled by `risk-service`.
* Customer identity and authentication: Handled by `account-service`.

## 4. Key channels and endpoints

### WebSocket endpoints
* Connection URL: `ws://localhost:8080/ws` (routed via gateway)
* Destination topic: `/topic/transfers/{userId}` (subscribes to personal transaction updates)
* Broadcast topic: `/topic/system/announcements` (general service status)

### REST endpoints
| Method | Path | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/notifications/send` | Manual or test notification dispatch trigger. |
| `GET` | `/api/v1/notifications/history/{userId}` | Retrieves past notification history for customer. |
| `GET` | `/actuator/health` | Service health and broker connectivity status. |

## 5. Critical invariants for AI agents

1. Zero SMS OTP enforcement: Under BSP Circular 1213, SMS must never be used to send transaction authorization codes or login OTPs. Out-of-band SMS delivery is restricted exclusively to informational transaction receipts (such as "₱1,000 sent to Account ••••1234").
2. Fire-and-forget isolation: Notification delivery failures must never block, delay, or roll back core ledger transactions. All communication occurs asynchronously via Kafka consumers.
3. Idempotent delivery: Kafka consumers must track processed message offsets or message IDs in Redis to avoid spamming customers with duplicate receipts during consumer group rebalancing.
4. Data privacy: Never include full account numbers, unmasked tax identification numbers, or raw passwords in notification payloads. Mask accounts to the last 4 digits (e.g., `••••4821`).

## 6. Local development and testing

Run the service locally:

```bash
cd backend/notification-service
mvn clean test
mvn spring-boot:run
```

Environment variables:
* `SERVER_PORT`: Port number (default: `8083`)
* `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (default: `localhost:9092`)
* `SPRING_MAIL_HOST`: SMTP host for email delivery
* `SPRING_MAIL_PORT`: SMTP port
* `REDIS_HOST`: Redis hostname for deduplication cache
