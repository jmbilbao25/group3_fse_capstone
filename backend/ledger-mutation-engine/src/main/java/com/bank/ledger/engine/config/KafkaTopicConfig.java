package com.bank.ledger.engine.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    @Value("${app.kafka.topics.transaction-events:transaction-events}")
    private String transactionEventsTopic;

    @Value("${app.kafka.topics.notification-alerts:notification-alerts}")
    private String notificationAlertsTopic;

    @Value("${app.kafka.topics.audit-events:audit-events}")
    private String auditEventsTopic;

    // Banking Standard: 3 partitions allows parallel consumer scaling
    @Bean
    public NewTopic transactionEventsTopic() {
        return TopicBuilder.name(transactionEventsTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }

    @Bean
    public NewTopic notificationAlertsTopic() {
        return TopicBuilder.name(notificationAlertsTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }

    @Bean
    public NewTopic auditEventsTopic() {
        return TopicBuilder.name(auditEventsTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }
}