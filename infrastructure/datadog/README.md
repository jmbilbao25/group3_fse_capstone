# Datadog Full-Stack Observability & APM Tracing

The core retail banking platform uses **Datadog Agent 7** to unify distributed tracing, APM request waterfall graphs, container logs, Redis cache telemetry, and infrastructure metrics under a single pane of glass.

## Features

1. **APM Request Tracing & Waterfall Visualizer**:
   - Ingests OpenTelemetry (OTLP) traces via HTTP (`http://localhost:4318/v1/traces`) and gRPC (`localhost:4317`).
   - Supports native Datadog trace clients via TCP port `8126`.
   - Propagates standard W3C `traceparent` context headers across all microservices (`gateway-service`, `account-service`, `ledger-mutation-engine`, and `notification-service`).
   - Generates interactive span waterfall graphs showing perimeter routing latency, database query execution, pessimistic lock hold duration, and Kafka event publishing.

2. **Redis Cache Metrics & Log Streaming**:
   - Container `redis-cache` runs on port `6379`.
   - Automatically monitored via Datadog Autodiscovery labels for memory utilization, hit/miss ratios, connected clients, operations/sec, and container log tailing (`redisdb` check).

3. **Kafka Event Streaming & Consumer Lag Telemetry**:
   - Container `kafka-broker` runs on ports `9092` (internal `29092`) and `9999` (JMX).
   - Monitored via Datadog Autodiscovery labels for consumer lag, broker offsets, consumer group highwatermarks, and container log tailing (`kafka_consumer` check).
   - JMX remote metrics enabled on port `9999` for broker throughput and partition replication metrics (`kafka` check).

4. **Unified Container Log Tailing**:
   - Automatically streams container logs from all services into the Datadog Log Explorer (`https://app.datadoghq.com/logs`).
   - Correlates logs with traces via MDC tags (`traceId`, `spanId`).

5. **Metrics & DogStatsD**:
   - Ingests host, container, and application metrics via DogStatsD on UDP port `8125`.

## How to Run Microservices with Datadog APM Java Agent

The Java tracer agent has been downloaded to `C:\datadog\dd-java-agent.jar` (and mirrored in `infrastructure/datadog/dd-java-agent.jar`).

### Option A: Using the PowerShell Runner
Run from the `backend/` directory:

```powershell
# Run API Gateway
.\start-services-datadog.ps1 -Service gateway-service

# Run Ledger Mutation Engine
.\start-services-datadog.ps1 -Service ledger-mutation-engine

# Run Account Service
.\start-services-datadog.ps1 -Service account-service

# Run Notification Service
.\start-services-datadog.ps1 -Service notification-service
```

### Option B: Running with Maven directly
```powershell
cd backend
.\mvnw.cmd spring-boot:run -pl gateway-service `
  -Dspring-boot.run.jvmArguments="-javaagent:C:\datadog\dd-java-agent.jar -Ddd.service=gateway-service -Ddd.env=local -Ddd.logs.injection=true -Ddd.agent.host=localhost -Ddd.agent.port=8126"
```

### Option C: Running packaged JAR files directly
```powershell
java -javaagent:C:\datadog\dd-java-agent.jar `
     -Ddd.service=gateway-service `
     -Ddd.env=local `
     -Ddd.logs.injection=true `
     -Ddd.agent.host=localhost `
     -Ddd.agent.port=8126 `
     -jar backend/gateway-service/target/gateway-service-1.0.0-SNAPSHOT.jar
```

## Container Configuration (infrastructure/docker-compose.yml)

The agent runs as container `dd-agent` inside Docker attached to `banking-net`:

```yaml
dd-agent:
  container_name: dd-agent
  image: registry.datadoghq.com/agent:7
  restart: unless-stopped
  ports:
    - "8126:8126"       # APM trace receiver
    - "8125:8125/udp"   # DogStatsD metrics
    - "4318:4318"       # OTLP HTTP receiver (Spring Boot trace intake)
    - "4317:4317"       # OTLP gRPC receiver
  environment:
    - DD_API_KEY=38f78a4f829a542181926e4e9499146d
    - DD_SITE=datadoghq.com
    - DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
    - DD_APM_ENABLED=true
    - DD_APM_NON_LOCAL_TRAFFIC=true
    - DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT=0.0.0.0:4318
    - DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_GRPC_ENDPOINT=0.0.0.0:4317
    - DD_LOGS_ENABLED=true
    - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
    - DD_PROCESS_AGENT_ENABLED=true
    - DD_SKIP_SSL_VALIDATION=true
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /proc/:/host/proc/:ro
    - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
  networks:
    - banking-net
```

## Useful Datadog Links

- **APM Traces & Waterfall Graphs**: [https://app.datadoghq.com/apm/traces](https://app.datadoghq.com/apm/traces)
- **Service Catalog**: [https://app.datadoghq.com/services](https://app.datadoghq.com/services)
- **Log Explorer**: [https://app.datadoghq.com/logs](https://app.datadoghq.com/logs)
- **Infrastructure & Container Overview**: [https://app.datadoghq.com/infrastructure](https://app.datadoghq.com/infrastructure)
