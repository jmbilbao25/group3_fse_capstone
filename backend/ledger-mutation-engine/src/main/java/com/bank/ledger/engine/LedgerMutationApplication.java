package com.bank.ledger.engine;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;

@SpringBootApplication
public class LedgerMutationApplication {

    public static void main(String[] args) {
        SpringApplication.run(LedgerMutationApplication.class, args);
    }
}
