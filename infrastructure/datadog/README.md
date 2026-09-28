# Datadog Full-Stack Observability & APM Tracing

The core retail banking platform uses **Datadog Agent 7** to unify distributed tracing, APM request waterfall graphs, container logs, and infrastructure metrics under a single pane of glass.

## Features

1. **APM Request Tracing & Waterfall Visualizer**:
   - Ingests OpenTelemetry (OTLP) traces via HTTP (`http://localhost:4318/v1/traces`) and gRPC (`localhost:4317`).
   - Supports native Datadog trace clients via TCP port `8126`.
   - Propagates standard W3C `traceparent` context headers across all microservices (`gateway-service`, `account-service`, `ledger-mutation-engine`, and `notification-service`).
   - Generates interactive span waterfall graphs showing perimeter routing latency, database query execution, pessimistic lock hold duration, and Kafka event publishing.

2. **Unified Container Log Tailing**:
   - Automatically streams container logs from all services into the Datadog Log Explorer (`https://app.datadoghq.com/logs`).
   - Correlates logs with traces via MDC tags (`traceId`, `spanId`).

3. **Metrics & DogStatsD**:
   - Ingests host, container, and application metrics via DogStatsD on UDP port `8125`.

## Container Configuration

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
