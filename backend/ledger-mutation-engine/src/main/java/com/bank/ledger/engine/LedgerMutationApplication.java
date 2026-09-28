package com.bank.ledger.engine;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class LedgerMutationApplication {

    public static void main(String[] args) {
        SpringApplication.run(LedgerMutationApplication.class, args);
    }
}