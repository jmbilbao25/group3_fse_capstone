package com.fse.banking.ledger.config;

import io.opentelemetry.api.baggage.propagation.W3CBaggagePropagator;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.propagation.TextMapPropagator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenTelemetry and distributed tracing configuration for Ledger Mutation Engine.
 *
 * <p>Explicitly registers standard W3C Trace Context and Baggage propagators
 * to ensure inbound and outbound trace context propagation across distributed services.</p>
 */
@Configuration
public class OpenTelemetryConfig {

    @Bean
    public TextMapPropagator w3cTraceContextPropagator() {
        return TextMapPropagator.composite(
                W3CTraceContextPropagator.getInstance(),
                W3CBaggagePropagator.getInstance()
        );
    }
}
