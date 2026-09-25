package com.bank.ledger.notification.service;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.NumberFormat;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.Locale;

@Component
public class ReceiptGenerator {

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter
            .ofPattern("yyyy-MM-dd HH:mm:ss z")
            .withZone(ZoneId.of("Asia/Manila"));

    public String formatCurrencyPhp(BigDecimal amount) {
        if (amount == null) {
            return "PHP 0.00";
        }
        NumberFormat currencyFormat = NumberFormat.getCurrencyInstance(new Locale("en", "PH"));
        return currencyFormat.format(amount).replace("PHP", "PHP ");
    }

    public String formatTimestamp(Instant timestamp) {
        if (timestamp == null) {
            timestamp = Instant.now();
        }
        return DATE_FORMATTER.format(timestamp);
    }

    public String maskAccountNumber(String accountId) {
        if (accountId == null || accountId.length() < 7) {
            return accountId != null ? accountId : "N/A";
        }
        String prefix = accountId.substring(0, 4);
        String suffix = accountId.substring(accountId.length() - 3);
        return prefix + "-****-" + suffix;
    }

    public String generateVerificationHash(String transferId, String sourceAccount, BigDecimal amount, Instant timestamp) {
        try {
            String rawData = String.format("%s|%s|%s|%s|BANK-LEDGER-PH",
                    transferId, sourceAccount, amount != null ? amount.toPlainString() : "0.00", timestamp);
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encodedhash = digest.digest(rawData.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(encodedhash).substring(0, 32).toUpperCase();
        } catch (NoSuchAlgorithmException e) {
            return "HASH-ERR-" + System.currentTimeMillis();
        }
    }
}
