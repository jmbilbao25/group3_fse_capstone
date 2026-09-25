package com.bank.ledger.engine;

import com.bank.ledger.engine.entity.audit.LedgerMutationAudit;
import com.bank.ledger.engine.repository.audit.LedgerMutationAuditRepository;
import com.zaxxer.hikari.HikariDataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class PostgresHikariTest {

    @Autowired
    @Qualifier("postgresAuditDataSource")
    private DataSource postgresDataSource;

    @Autowired
    private LedgerMutationAuditRepository auditRepository;

    @Test
    @DisplayName("Verify HikariCP Pool Dimensions (max=30, min=5, pool-name)")
    void verifyHikariPoolDimensions() {
        assertNotNull(postgresDataSource, "DataSource should not be null");
        assertTrue(postgresDataSource instanceof HikariDataSource, "DataSource should be HikariDataSource");

        HikariDataSource hikariDs = (HikariDataSource) postgresDataSource;

        System.out.println("==========================================================");
        System.out.println(">>> HIKARICP POOL VERIFICATION <<<");
        System.out.println("Pool Name:          " + hikariDs.getPoolName());
        System.out.println("Maximum Pool Size:  " + hikariDs.getMaximumPoolSize());
        System.out.println("Minimum Idle:       " + hikariDs.getMinimumIdle());
        System.out.println("Connection Timeout: " + hikariDs.getConnectionTimeout() + " ms");
        System.out.println("==========================================================");

        assertEquals("HikariPool-PostgresAudit", hikariDs.getPoolName());
        assertEquals(30, hikariDs.getMaximumPoolSize());
        assertEquals(5, hikariDs.getMinimumIdle());
    }

    @Test
    @DisplayName("Verify PostgreSQL Audit Read/Write via HikariCP")
    void testAuditInsertAndRead() {
        String txId = "TEST-TX-" + System.currentTimeMillis();

        LedgerMutationAudit audit = LedgerMutationAudit.builder()
                .transactionId(txId)
                .accountId("A2001")
                .mutationType("TRANSFER")
                .mutationAmount(new BigDecimal("1500.0000"))
                .beforeBalance(new BigDecimal("10000.0000"))
                .afterBalance(new BigDecimal("8500.0000"))
                .initiatorUserId("U1001")
                .status("COMMITTED")
                .createdAt(Instant.now())
                .build();

        LedgerMutationAudit saved = auditRepository.save(audit);
        assertNotNull(saved.getAuditId(), "Audit ID should be generated");

        Optional<LedgerMutationAudit> retrieved = auditRepository.findByTransactionId(txId);
        assertTrue(retrieved.isPresent(), "Saved audit should be retrievable");
        assertEquals(new BigDecimal("1500.0000"), retrieved.get().getMutationAmount());
    }
}
