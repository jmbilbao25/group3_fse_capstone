package com.bank.ledger.notification;

import com.bank.ledger.notification.service.ReceiptGenerator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class ReceiptGeneratorTest {

    private ReceiptGenerator generator;

    @BeforeEach
    void setUp() {
        generator = new ReceiptGenerator();
    }

    @Test
    @DisplayName("Should correctly format currency in Philippine Pesos")
    void shouldFormatCurrencyPhp() {
        BigDecimal amount = new BigDecimal("50000.00");
        String formatted = generator.formatCurrencyPhp(amount);
        assertNotNull(formatted);
        assertTrue(formatted.contains("50,000.00"), "Formatted string should contain 50,000.00");
    }

    @Test
    @DisplayName("Should mask account number for security compliance")
    void shouldMaskAccountNumber() {
        String accountId = "ACC-1002938471";
        String masked = generator.maskAccountNumber(accountId);
        assertEquals("ACC--****-471", masked);
    }

    @Test
    @DisplayName("Should generate 32-character hexadecimal SHA-256 verification hash")
    void shouldGenerateVerificationHash() {
        String hash = generator.generateVerificationHash(
                "TRX-8921-A98F",
                "ACC-1002938471",
                new BigDecimal("50000.00"),
                Instant.now()
        );
        assertNotNull(hash);
        assertEquals(32, hash.length());
        assertTrue(hash.matches("^[0-9A-F]{32}$"), "Hash must be 32-character uppercase hex string");
    }
}
