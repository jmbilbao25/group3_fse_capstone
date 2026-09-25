package com.bank.ledger.engine;

import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.engine.entity.master.BalanceMaster;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.service.BalanceMutationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class PessimisticLockConcurrencyTest {

    @Autowired
    private BalanceMutationService mutationService;

    @Autowired
    private BalanceMasterRepository balanceRepository;

    private static final String SENDER_ID = "acc-2001-sav-001";
    private static final String RECEIVER_ID = "acc-2002-chk-001";

    @BeforeEach
    void setupAccounts() {
        // Reset Sender with exactly PHP 10,000.00
        BalanceMaster sender = balanceRepository.findById(SENDER_ID).orElseGet(() ->
                BalanceMaster.builder().accountId(SENDER_ID).build());
        sender.setBalanceAmount(new BigDecimal("10000.0000"));
        sender.setHoldAmount(BigDecimal.ZERO);
        sender.setAvailableBalance(new BigDecimal("10000.0000"));
        sender.setCreatedAt(Instant.now());
        sender.setUpdatedAt(Instant.now());
        balanceRepository.save(sender);

        // Reset Receiver with exactly PHP 5,000.00
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ID).orElseGet(() ->
                BalanceMaster.builder().accountId(RECEIVER_ID).build());
        receiver.setBalanceAmount(new BigDecimal("5000.0000"));
        receiver.setHoldAmount(BigDecimal.ZERO);
        receiver.setAvailableBalance(new BigDecimal("5000.0000"));
        receiver.setCreatedAt(Instant.now());
        receiver.setUpdatedAt(Instant.now());
        balanceRepository.save(receiver);
    }

    @Test
    @DisplayName("Pessimistic Locking Test: Two Concurrent 8,000 PHP Transfers against 10,000 PHP Balance")
    void testConcurrentTransfersPreventDoubleSpending() throws InterruptedException {
        int threads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch readyLatch = new CountDownLatch(threads);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch finishLatch = new CountDownLatch(threads);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);

        for (int i = 1; i <= threads; i++) {
            final int index = i;
            executor.submit(() -> {
                readyLatch.countDown();
                try {
                    // All threads wait here until released simultaneously
                    startLatch.await();

                    MutationRequest request = MutationRequest.builder()
                            .transactionId("CONCUR-" + UUID.randomUUID().toString().substring(0, 8) + "-" + index)
                            .accountId(SENDER_ID)
                            .targetAccountId(RECEIVER_ID)
                            .eventType(EventType.TRANSFER)
                            .mutationType(MutationType.TRANSFER)
                            .mutationAmount(new BigDecimal("8000.0000"))
                            .initiatorUserId("usr-1001-cst-001")
                            .build();

                    mutationService.executeTransfer(request);
                    successCount.incrementAndGet();
                } catch (InsufficientFundsException ex) {
                    failureCount.incrementAndGet();
                } catch (Exception e) {
                    System.err.println("Unexpected exception: " + e.getMessage());
                } finally {
                    finishLatch.countDown();
                }
            });
        }

        // Wait until all threads are prepped
        readyLatch.await();
        // FIRE SIMULTANEOUSLY!
        startLatch.countDown();
        finishLatch.await(10, TimeUnit.SECONDS);

        BalanceMaster finalSender = balanceRepository.findById(SENDER_ID).orElseThrow();
        BalanceMaster finalReceiver = balanceRepository.findById(RECEIVER_ID).orElseThrow();

        System.out.println("==========================================================");
        System.out.println(">>> PESSIMISTIC LOCK CONCURRENCY TEST RESULTS <<<");
        System.out.println("Successful Transfers (8,000 PHP): " + successCount.get());
        System.out.println("Rejected Transfers (Insufficient): " + failureCount.get());
        System.out.println("Final Sender Balance:   PHP " + finalSender.getBalanceAmount());
        System.out.println("Final Receiver Balance: PHP " + finalReceiver.getBalanceAmount());
        System.out.println("==========================================================");

        // Verification: Exactly 1 must succeed, exactly 1 must fail!
        assertEquals(1, successCount.get(), "Exactly 1 concurrent transfer should succeed");
        assertEquals(1, failureCount.get(), "Second transfer must be blocked by lock & rejected for insufficient funds");
        assertEquals(0, new BigDecimal("2000.0000").compareTo(finalSender.getBalanceAmount()), "Sender balance must be exactly 2,000 PHP (10,000 - 8,000)");
        assertEquals(0, new BigDecimal("13000.0000").compareTo(finalReceiver.getBalanceAmount()), "Receiver balance must be exactly 13,000 PHP (5,000 + 8,000)");
    }
}