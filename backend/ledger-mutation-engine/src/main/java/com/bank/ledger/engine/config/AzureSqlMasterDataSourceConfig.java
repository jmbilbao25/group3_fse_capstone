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
import org.springframework.context.annotation.Profile;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

/**
 * Cloud Native Datasource Configuration: Azure SQL Database
 * Replaces Oracle XE in the "azure" Spring profile.
 * Provides pessimistic row-locking via Microsoft SQL Server dialect (UPDLOCK, ROWLOCK).
 */
@Configuration
@Profile("azure")
@EnableTransactionManagement
@EnableJpaRepositories(
    basePackages = "com.bank.ledger.engine.repository.master",
    entityManagerFactoryRef = "azureSqlEntityManagerFactory",
    transactionManagerRef = "azureSqlTransactionManager"
)
public class AzureSqlMasterDataSourceConfig {

    @Primary
    @Bean
    @ConfigurationProperties("spring.datasource.master")
    public DataSourceProperties azureSqlDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Primary
    @Bean(name = {"azureSqlMasterDataSource", "oracleMasterDataSource"})
    @ConfigurationProperties("spring.datasource.master.hikari")
    public DataSource azureSqlMasterDataSource() {
        return azureSqlDataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Primary
    @Bean(name = {"azureSqlEntityManagerFactory", "oracleEntityManagerFactory"})
    public LocalContainerEntityManagerFactoryBean azureSqlEntityManagerFactory(
            EntityManagerFactoryBuilder builder,
            @Qualifier("azureSqlMasterDataSource") DataSource dataSource) {

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
    @Bean(name = {"azureSqlTransactionManager", "oracleTransactionManager"})
    public PlatformTransactionManager azureSqlTransactionManager(
            @Qualifier("azureSqlEntityManagerFactory") EntityManagerFactory entityManagerFactory) {
        return new JpaTransactionManager(entityManagerFactory);
    }
}
