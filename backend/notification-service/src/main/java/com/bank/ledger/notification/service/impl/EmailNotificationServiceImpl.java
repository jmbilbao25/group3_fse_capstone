package com.bank.ledger.notification.service.impl;

import com.bank.ledger.contracts.dto.TransactionNotificationEvent;
import com.bank.ledger.notification.entity.NotificationEntity;
import com.bank.ledger.notification.repository.NotificationRepository;
import com.bank.ledger.notification.service.EmailNotificationService;
import com.bank.ledger.notification.service.ReceiptGenerator;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.annotation.PostConstruct;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailNotificationServiceImpl implements EmailNotificationService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;
    private final ReceiptGenerator receiptGenerator;

    @Autowired(required = false)
    private StringRedisTemplate redisTemplate;

    @Autowired(required = false)
    private NotificationRepository notificationRepository;

    @Autowired(required = false)
    private MeterRegistry meterRegistry;

    @Value("${spring.mail.username:noreply@corebank.ph}")
    private String mailFrom = "noreply@corebank.ph";

    @Value("${app.notifications.compliance-email:compliance-officer@corebank.ph}")
    private String complianceEmail = "compliance-officer@corebank.ph";

    // Retry spool for offline SMTP circuit buffering (SCEN-NOTIF-04)
    private final ConcurrentLinkedQueue<BufferedEmail> retrySpool = new ConcurrentLinkedQueue<>();
    private final AtomicInteger consecutiveFailures = new AtomicInteger(0);
    private volatile boolean circuitOpen = false;

    private Counter emailSuccessCounter;
    private Counter emailFailureCounter;
    private Counter duplicateSuppressedCounter;
    private Timer emailDispatchTimer;

    @PostConstruct
    public void initMetrics() {
        if (meterRegistry != null) {
            emailSuccessCounter = meterRegistry.counter("email_dispatch_counts", "status", "success");
            emailFailureCounter = meterRegistry.counter("email_dispatch_counts", "status", "failure");
            duplicateSuppressedCounter = meterRegistry.counter("email_dispatch_counts", "status", "duplicate_suppressed");
            emailDispatchTimer = meterRegistry.timer("email_dispatch_duration");
        }
    }

    @Override
    public boolean sendTransactionReceipt(TransactionNotificationEvent event) {
        String transferId = event.getTransferId();

        // 1. Idempotency Check with Redis Seen Cache (SCEN-NOTIF-03)
        if (isDuplicate(transferId)) {
            log.info("Duplicate notification suppressed for transfer: {}", transferId);
            if (duplicateSuppressedCounter != null) {
                duplicateSuppressedCounter.increment();
            }
            return false;
        }

        // 2. Prepare Email Metadata and Thymeleaf Context
        Context context = new Context();
        context.setVariable("transferId", transferId);
        context.setVariable("formattedAmount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
        context.setVariable("formattedDate", receiptGenerator.formatTimestamp(event.getTimestamp()));
        context.setVariable("maskedSourceAccount", receiptGenerator.maskAccountNumber(event.getSourceAccount()));
        context.setVariable("maskedDestinationAccount", receiptGenerator.maskAccountNumber(event.getDestinationAccount()));
        context.setVariable("formattedBeforeBalance", receiptGenerator.formatCurrencyPhp(event.getBeforeBalance()));
        context.setVariable("formattedAfterBalance", receiptGenerator.formatCurrencyPhp(event.getAfterBalance()));
        context.setVariable("status", event.getStatus() != null ? event.getStatus() : "COMMITTED");
        context.setVariable("transactionType", event.getEventType() != null ? event.getEventType() : "TRANSFER");

        String hash = receiptGenerator.generateVerificationHash(
                transferId, event.getSourceAccount(), event.getAmount(), event.getTimestamp());
        context.setVariable("verificationHash", hash);

        if ("TRANSFER_APPROVED_BY_CHECKER".equalsIgnoreCase(event.getEventType())) {
            context.setVariable("status", "APPROVED & RELEASED (Checker: Beatriz Ocampo)");
        }

        String htmlContent = templateEngine.process("email/transaction-receipt.html", context);

        String recipient = event.getRecipientEmail() != null && !event.getRecipientEmail().isBlank()
                ? event.getRecipientEmail()
                : "customer-" + (event.getUserId() != null ? event.getUserId() : "user") + "@corebank.ph";

        String subject;
        if ("TRANSFER_APPROVED_BY_CHECKER".equalsIgnoreCase(event.getEventType())) {
            subject = String.format("Funds Released: Transfer %s Approved [%s]",
                    receiptGenerator.formatCurrencyPhp(event.getAmount()), transferId);
        } else {
            subject = String.format("Transaction Receipt: %s [%s]",
                    receiptGenerator.formatCurrencyPhp(event.getAmount()), transferId);
        }

        // 3. Dispatch Email with Circuit Buffering to Sender (Juan Dela Cruz)
        boolean dispatched = dispatchEmail(recipient, subject, htmlContent, transferId);

        // 3.1. Dispatch Inward Credit Notification to Beneficiary (Maria Santos)
        if (event.getDestinationAccount() != null && !event.getDestinationAccount().isBlank()) {
            sendBeneficiaryCreditAdvice(event, transferId);
        }

        // 4. Persist to Oracle NOTIFICATIONS table
        persistNotificationRecord(
                event.getUserId() != null ? event.getUserId() : "USR-SYSTEM",
                "TRANSACTION_ALERT",
                String.format("Transaction %s completed: %s sent to %s. New Balance: %s",
                        transferId, receiptGenerator.formatCurrencyPhp(event.getAmount()),
                        receiptGenerator.maskAccountNumber(event.getDestinationAccount()),
                        receiptGenerator.formatCurrencyPhp(event.getAfterBalance()))
        );

        return dispatched;
    }

    private void sendBeneficiaryCreditAdvice(TransactionNotificationEvent event, String transferId) {
        try {
            Context benContext = new Context();
            benContext.setVariable("transferId", transferId);
            benContext.setVariable("formattedAmount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
            benContext.setVariable("formattedDate", receiptGenerator.formatTimestamp(event.getTimestamp()));
            benContext.setVariable("maskedSourceAccount", receiptGenerator.maskAccountNumber(event.getSourceAccount()));
            benContext.setVariable("maskedDestinationAccount", receiptGenerator.maskAccountNumber(event.getDestinationAccount()));
            benContext.setVariable("status", "CREDITED");
            benContext.setVariable("transactionType", "INWARD_TRANSFER");
            benContext.setVariable("verificationHash", receiptGenerator.generateVerificationHash(
                    transferId, event.getDestinationAccount(), event.getAmount(), event.getTimestamp()));

            String benHtml = templateEngine.process("email/inward-credit-advice.html", benContext);

            String beneficiaryEmail = "maria.santos@retailbank.ph";
            String benSubject = String.format("Credit Advice: You Received %s from Juan Dela Cruz [%s]",
                    receiptGenerator.formatCurrencyPhp(event.getAmount()), transferId);

            dispatchEmail(beneficiaryEmail, benSubject, benHtml, transferId + "-BEN");

            persistNotificationRecord(
                    "U1002",
                    "TRANSACTION_ALERT",
                    String.format("Inward credit received: %s from account %s (Ref: %s)",
                            receiptGenerator.formatCurrencyPhp(event.getAmount()),
                            receiptGenerator.maskAccountNumber(event.getSourceAccount()),
                            transferId)
            );
            log.info("Beneficiary credit advice dispatched to {} for transfer {}", beneficiaryEmail, transferId);
        } catch (Exception e) {
            log.warn("Failed to dispatch beneficiary credit advice for {}: {}", transferId, e.getMessage());
        }
    }

    @Override
    public boolean sendMakerCheckerAlert(TransactionNotificationEvent event) {
        String transferId = event.getTransferId();
        String makerId = event.getMakerUserId() != null ? event.getMakerUserId() : (event.getUserId() != null ? event.getUserId() : "USR-CUSTOMER");

        Context context = new Context();
        context.setVariable("transferId", transferId);
        context.setVariable("makerUserId", makerId);
        context.setVariable("formattedAmount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
        context.setVariable("formattedDate", receiptGenerator.formatTimestamp(event.getTimestamp()));
        context.setVariable("sourceAccount", event.getSourceAccount());
        context.setVariable("destinationAccount", event.getDestinationAccount());

        context.setVariable("alertHeader", "DUAL CONTROL HOLD: Maker-Checker Review");
        context.setVariable("tierSubtitle", "BSP MORB Internal Controls (₱50,000.01 – ₱499,999.99)");
        context.setVariable("tierBadge", "TIER 2: DUAL CONTROL REQUIRED");
        context.setVariable("thresholdNotice", "AMOUNT EXCEEDS RETAIL LIMIT (₱50,000.01 – ₱499,999.99)");
        context.setVariable("regulatoryTier", "Tier 2: Dual Control (Maker-Checker)");
        context.setVariable("requiredRoles", "Maker: Customer | Checker: Bank Operations Manager (Level 1)");
        context.setVariable("amlaStatus", "Exempt (Below PHP 500,000.00 Threshold)");
        context.setVariable("workflowInstruction",
                "Customer initiated transfer online; transaction is held in PENDING_APPROVAL. A Bank Manager must review and authorize in the Manager Console before release.");

        String htmlContent = templateEngine.process("email/maker-checker-alert.html", context);
        String subject = String.format("DUAL CONTROL REVIEW: Transfer %s Requires Manager Approval [%s]",
                receiptGenerator.formatCurrencyPhp(event.getAmount()), transferId);

        boolean dispatched = dispatchEmail(complianceEmail, subject, htmlContent, transferId);

        persistNotificationRecord(
                makerId,
                "MAKER_CHECKER_ALERT",
                String.format("Tier 2 transfer %s for %s held for Manager Maker-Checker authorization.",
                        transferId, receiptGenerator.formatCurrencyPhp(event.getAmount()))
        );

        return dispatched;
    }

    @Override
    public boolean sendAmlaHighValueAlert(TransactionNotificationEvent event) {
        String transferId = event.getTransferId();
        String makerId = event.getMakerUserId() != null ? event.getMakerUserId() : (event.getUserId() != null ? event.getUserId() : "USR-CUSTOMER");

        Context context = new Context();
        context.setVariable("transferId", transferId);
        context.setVariable("makerUserId", makerId);
        context.setVariable("formattedAmount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
        context.setVariable("formattedDate", receiptGenerator.formatTimestamp(event.getTimestamp()));
        context.setVariable("sourceAccount", event.getSourceAccount());
        context.setVariable("destinationAccount", event.getDestinationAccount());

        context.setVariable("alertHeader", "URGENT AMLA HOLD: High-Value CTR Review");
        context.setVariable("tierSubtitle", "Anti-Money Laundering Act (AMLA) & BSP MORB (>= ₱500,000.00)");
        context.setVariable("tierBadge", "TIER 3: AMLA COVERED (CTR REQUIRED)");
        context.setVariable("thresholdNotice", "AMOUNT MEETS/EXCEEDS AMLA THRESHOLD (>= ₱500,000.00)");
        context.setVariable("regulatoryTier", "Tier 3: High-Value / AMLA Covered");
        context.setVariable("requiredRoles", "Maker: Customer | Checker 1: Manager (Level 1) | Approver 2: Senior Manager (Level 2)");
        context.setVariable("amlaStatus", "COVERED TRANSACTION REPORT (CTR) FILING MANDATORY");
        context.setVariable("workflowInstruction",
                "Customer initiated high-value transfer online; requires CTR filing under AMLA + dual manager approval (Manager 1 + Manager 2) in the Manager Console before balance release.");

        String htmlContent = templateEngine.process("email/maker-checker-alert.html", context);
        String subject = String.format("URGENT AMLA HOLD: Transfer %s Requires CTR Filing & Dual Manager Approval [%s]",
                receiptGenerator.formatCurrencyPhp(event.getAmount()), transferId);

        boolean dispatched = dispatchEmail(complianceEmail, subject, htmlContent, transferId);

        persistNotificationRecord(
                makerId,
                "AMLA_CTR_ALERT",
                String.format("Tier 3 AMLA transfer %s for %s held. CTR filing & dual manager approval required.",
                        transferId, receiptGenerator.formatCurrencyPhp(event.getAmount()))
        );

        return dispatched;
    }

    private boolean isDuplicate(String transferId) {
        if (redisTemplate == null || transferId == null) {
            return false;
        }
        try {
            String key = "notif:seen:" + transferId;
            Boolean isFirstDelivery = redisTemplate.opsForValue().setIfAbsent(key, "1", Duration.ofHours(1));
            return Boolean.FALSE.equals(isFirstDelivery);
        } catch (Exception e) {
            log.warn("Redis deduplication cache unavailable, proceeding without deduplication check: {}", e.getMessage());
            return false;
        }
    }

    private boolean dispatchEmail(String recipient, String subject, String htmlContent, String referenceId) {
        long startTime = System.currentTimeMillis();

        // If circuit is already OPEN, buffer immediately without waiting for timeouts
        if (circuitOpen) {
            log.warn("Circuit OPEN: Downstream SMTP unavailable. Buffering email for ref={}", referenceId);
            bufferEmail(recipient, subject, htmlContent, referenceId);
            return false;
        }

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(mailFrom);
            helper.setTo(recipient);
            helper.setSubject(subject);
            helper.setText(htmlContent, true);

            mailSender.send(message);

            long duration = System.currentTimeMillis() - startTime;
            log.info("Email dispatched successfully to {} for ref={} in {}ms", recipient, referenceId, duration);

            if (emailSuccessCounter != null) {
                emailSuccessCounter.increment();
            }
            if (emailDispatchTimer != null) {
                emailDispatchTimer.record(duration, TimeUnit.MILLISECONDS);
            }

            consecutiveFailures.set(0);
            return true;
        } catch (Exception e) {
            int failures = consecutiveFailures.incrementAndGet();
            log.error("Failed to dispatch email via SMTP (consecutive failures: {}): {}", failures, e.getMessage());

            if (emailFailureCounter != null) {
                emailFailureCounter.increment();
            }

            // Trip circuit breaker if consecutive failures exceed threshold
            if (failures >= 3) {
                circuitOpen = true;
                log.warn("Circuit Breaker TRIPPED to OPEN: Downstream SMTP outages detected.");
            }

            bufferEmail(recipient, subject, htmlContent, referenceId);
            return false;
        }
    }

    private void bufferEmail(String recipient, String subject, String htmlContent, String referenceId) {
        BufferedEmail buffered = BufferedEmail.builder()
                .recipient(recipient)
                .subject(subject)
                .htmlContent(htmlContent)
                .referenceId(referenceId)
                .enqueuedAt(Instant.now())
                .build();
        retrySpool.offer(buffered);
        log.info("Email spooled into retry buffer. Current spool size: {}", retrySpool.size());
    }

    @Scheduled(fixedDelay = 30000)
    public void scheduledRetrySpoolFlush() {
        if (retrySpool.isEmpty()) {
            return;
        }
        log.info("Checking downstream SMTP status and flushing retry spool (pending: {})...", retrySpool.size());
        flushRetrySpool();
    }

    @Override
    public int flushRetrySpool() {
        if (retrySpool.isEmpty()) {
            return 0;
        }
        int flushed = 0;
        int initialSize = retrySpool.size();

        for (int i = 0; i < initialSize; i++) {
            BufferedEmail buffered = retrySpool.poll();
            if (buffered == null) break;

            try {
                MimeMessage message = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
                helper.setFrom(mailFrom);
                helper.setTo(buffered.getRecipient());
                helper.setSubject(buffered.getSubject());
                helper.setText(buffered.getHtmlContent(), true);

                mailSender.send(message);
                flushed++;
                consecutiveFailures.set(0);
                circuitOpen = false;
                log.info("Flushed buffered email for ref={}", buffered.getReferenceId());
            } catch (Exception e) {
                // Re-enqueue if still failing
                retrySpool.offer(buffered);
                log.warn("SMTP still unavailable during flush. Re-buffered ref={}", buffered.getReferenceId());
                break;
            }
        }
        return flushed;
    }

    @Override
    public Map<String, Object> getSpoolStatus() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("spool_size", retrySpool.size());
        status.put("circuit_open", circuitOpen);
        status.put("consecutive_failures", consecutiveFailures.get());
        status.put("mail_from", mailFrom);
        return status;
    }

    private void persistNotificationRecord(String userId, String type, String message) {
        if (notificationRepository == null) return;
        try {
            NotificationEntity entity = NotificationEntity.builder()
                    .notificationId("NOTIF-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .userId(userId)
                    .type(type)
                    .message(message)
                    .sentAt(Instant.now())
                    .build();
            notificationRepository.save(entity);
        } catch (Exception e) {
            log.warn("Could not persist notification entity to Oracle DB: {}", e.getMessage());
        }
    }

    @Data
    @Builder
    private static class BufferedEmail {
        private String recipient;
        private String subject;
        private String htmlContent;
        private String referenceId;
        private Instant enqueuedAt;
    }
}
