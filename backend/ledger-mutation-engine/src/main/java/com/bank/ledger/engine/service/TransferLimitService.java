package com.bank.ledger.engine.service;

import com.bank.ledger.engine.entity.master.AccountMaster;
import com.bank.ledger.engine.entity.master.CustomerMaster;
import com.bank.ledger.engine.entity.master.KycTierLimit;
import com.bank.ledger.engine.exception.TransferLimitExceededException;
import com.bank.ledger.engine.repository.master.AccountMasterRepository;
import com.bank.ledger.engine.repository.master.CustomerMasterRepository;
import com.bank.ledger.engine.repository.master.KycTierLimitRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

/**
 * KYC tier limits. Counts every outgoing transfer that is settled or still on
 * hold, per Manila calendar day and month, across all of the customer's accounts.
 */
@Service
@RequiredArgsConstructor
public class TransferLimitService {

    static final ZoneId MANILA = ZoneId.of("Asia/Manila");

    private final CustomerMasterRepository customerRepository;
    private final KycTierLimitRepository tierRepository;
    private final AccountMasterRepository accountRepository;
    private final TransactionMasterRepository transactionRepository;

    public record Limits(String customerId, int kycTier, String tierName, String description,
                         BigDecimal perTransferLimit, BigDecimal dailyLimit, BigDecimal monthlyLimit,
                         BigDecimal usedToday, BigDecimal usedThisMonth,
                         BigDecimal remainingToday, BigDecimal remainingThisMonth) {
    }

    public Limits limitsFor(String customerId) {
        CustomerMaster customer = customerRepository.findById(customerId)
                .orElseThrow(() -> new IllegalArgumentException("Customer not found: " + customerId));
        KycTierLimit tier = tierRepository.findById(customer.getKycTier())
                .orElseThrow(() -> new IllegalStateException("No limits configured for tier " + customer.getKycTier()));

        List<String> accounts = accountRepository.findByUserId(customerId).stream().map(AccountMaster::getAccountId).toList();
        LocalDate today = LocalDate.now(MANILA);
        BigDecimal usedToday = used(accounts, today.atStartOfDay(MANILA).toInstant());
        BigDecimal usedMonth = used(accounts, today.withDayOfMonth(1).atStartOfDay(MANILA).toInstant());

        return new Limits(customerId, tier.getKycTier(), tier.getTierName(), tier.getDescription(),
                tier.getPerTxnLimit(), tier.getDailyLimit(), tier.getMonthlyLimit(), usedToday, usedMonth,
                tier.getDailyLimit().subtract(usedToday).max(BigDecimal.ZERO),
                tier.getMonthlyLimit().subtract(usedMonth).max(BigDecimal.ZERO));
    }

    /** Throws when {@code amount} would break the per-transfer, daily or monthly limit. */
    public void check(String customerId, BigDecimal amount) {
        Limits l = limitsFor(customerId);
        if (l.kycTier() == 0) {
            throw breach(l, "TIER", BigDecimal.ZERO, BigDecimal.ZERO,
                    "Verify your identity to start sending money. Unverified accounts can receive transfers only.");
        }
        if (amount.compareTo(l.perTransferLimit()) > 0) {
            throw breach(l, "PER_TRANSFER", l.perTransferLimit(), l.perTransferLimit(),
                    String.format("%s accounts can send up to PHP %,.2f per transfer.", l.tierName(), l.perTransferLimit()));
        }
        if (amount.compareTo(l.remainingToday()) > 0) {
            throw breach(l, "DAILY", l.dailyLimit(), l.remainingToday(),
                    String.format("This would exceed your PHP %,.2f daily limit. PHP %,.2f left today.", l.dailyLimit(), l.remainingToday()));
        }
        if (amount.compareTo(l.remainingThisMonth()) > 0) {
            throw breach(l, "MONTHLY", l.monthlyLimit(), l.remainingThisMonth(),
                    String.format("This would exceed your PHP %,.2f monthly limit. PHP %,.2f left this month.", l.monthlyLimit(), l.remainingThisMonth()));
        }
    }

    private BigDecimal used(List<String> accounts, Instant since) {
        if (accounts.isEmpty()) return BigDecimal.ZERO;
        BigDecimal sum = transactionRepository.sumOutgoingSince(accounts, since);
        return sum != null ? sum : BigDecimal.ZERO;
    }

    private static TransferLimitExceededException breach(Limits l, String type, BigDecimal limit, BigDecimal remaining, String msg) {
        return new TransferLimitExceededException(l.kycTier(), l.tierName(), type, limit, remaining, msg);
    }
}
