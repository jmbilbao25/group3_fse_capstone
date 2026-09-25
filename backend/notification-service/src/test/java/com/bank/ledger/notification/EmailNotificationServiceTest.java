package com.bank.ledger.notification;

import com.bank.ledger.contracts.dto.TransactionNotificationEvent;
import com.bank.ledger.notification.repository.NotificationRepository;
import com.bank.ledger.notification.service.ReceiptGenerator;
import com.bank.ledger.notification.service.impl.EmailNotificationServiceImpl;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EmailNotificationServiceTest {

    @Mock
    private JavaMailSender mailSender;

    @Mock
    private TemplateEngine templateEngine;

    @Spy
    private ReceiptGenerator receiptGenerator = new ReceiptGenerator();

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    @Mock
    private NotificationRepository notificationRepository;

    @InjectMocks
    private EmailNotificationServiceImpl emailService;

    private TransactionNotificationEvent sampleEvent;

    @BeforeEach
    void setUp() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(mailSender.createMimeMessage()).thenAnswer(inv -> new MimeMessage(Session.getInstance(new Properties())));

        sampleEvent = TransactionNotificationEvent.builder()
                .transferId("TRX-TEST-0001")
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-2009847192")
                .recipientEmail("customer@corebank.ph")
                .userId("USR-882190")
                .amount(new BigDecimal("50000.00"))
                .currency("PHP")
                .beforeBalance(new BigDecimal("25000000.00"))
                .afterBalance(new BigDecimal("24950000.00"))
                .status("COMMITTED")
                .eventType("TRANSFER_EXECUTED")
                .timestamp(Instant.now())
                .build();
    }

    @Test
    @DisplayName("Should format HTML template and send email receipt on first delivery")
    void shouldSendTransactionReceiptSuccessfully() {
        when(valueOperations.setIfAbsent(eq("notif:seen:TRX-TEST-0001"), eq("1"), any(Duration.class)))
                .thenReturn(true);

        when(templateEngine.process(eq("email/transaction-receipt.html"), any(Context.class)))
                .thenReturn("<html><body>Mock Receipt</body></html>");

        boolean result = emailService.sendTransactionReceipt(sampleEvent);

        assertTrue(result, "Email dispatch should succeed");
        verify(mailSender, times(1)).send(any(MimeMessage.class));
    }

    @Test
    @DisplayName("Should suppress duplicate email when already seen in Redis cache (SCEN-NOTIF-03)")
    void shouldSuppressDuplicateNotification() {
        // Returns false indicating key already exists
        when(valueOperations.setIfAbsent(eq("notif:seen:TRX-TEST-0001"), eq("1"), any(Duration.class)))
                .thenReturn(false);

        boolean result = emailService.sendTransactionReceipt(sampleEvent);

        assertFalse(result, "Duplicate email should be suppressed");
        verify(mailSender, never()).send(any(MimeMessage.class));
    }

    @Test
    @DisplayName("Should buffer email into retry spool when SMTP fails (SCEN-NOTIF-04)")
    void shouldBufferEmailWhenSmtpFails() {
        when(valueOperations.setIfAbsent(anyString(), anyString(), any(Duration.class)))
                .thenReturn(true);

        when(templateEngine.process(anyString(), any(Context.class)))
                .thenReturn("<html>Receipt</html>");

        doThrow(new MailSendException("SMTP Connection Refused"))
                .when(mailSender).send(any(MimeMessage.class));

        boolean result = emailService.sendTransactionReceipt(sampleEvent);

        assertFalse(result, "Send should return false when failing to live SMTP");
        Map<String, Object> spoolStatus = emailService.getSpoolStatus();
        assertEquals(1, spoolStatus.get("spool_size"), "Spool size should be 1 pending email");
    }

    @Test
    @DisplayName("Should dispatch Tier 2 Dual Control alert to Manager")
    void shouldSendTier2MakerCheckerAlert() {
        when(templateEngine.process(eq("email/maker-checker-alert.html"), any(Context.class)))
                .thenReturn("<html><body>Tier 2 Alert</body></html>");

        sampleEvent.setAmount(new BigDecimal("150000.00"));
        boolean result = emailService.sendMakerCheckerAlert(sampleEvent);

        assertTrue(result, "Tier 2 alert dispatch should succeed");
        verify(mailSender, times(1)).send(any(MimeMessage.class));
    }

    @Test
    @DisplayName("Should dispatch Tier 3 AMLA CTR alert for >= 500k")
    void shouldSendTier3AmlaHighValueAlert() {
        when(templateEngine.process(eq("email/maker-checker-alert.html"), any(Context.class)))
                .thenReturn("<html><body>Tier 3 AMLA Alert</body></html>");

        sampleEvent.setAmount(new BigDecimal("750000.00"));
        boolean result = emailService.sendAmlaHighValueAlert(sampleEvent);

        assertTrue(result, "Tier 3 AMLA alert dispatch should succeed");
        verify(mailSender, times(1)).send(any(MimeMessage.class));
    }
}
