package com.bank.ledger.gateway.security;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.JWSSigner;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;

class JwtTokenValidatorTest {

    private static final String USER_SECRET =
            "c3VwZXItc2VjcmV0LWtleS1mb3ItZnNlLWNhcHN0b25lLWJhbmtpbmctcGxhdGZvcm0tMjAyNi0xMjM0NTY3ODkwMTI=";

    private static final String ISSUER = "fse-banking-account-service";

    private JwtTokenValidator validator;

    @BeforeEach
    void setUp() {
        validator = new JwtTokenValidator(USER_SECRET, ISSUER);
    }

    private String createToken(String secret, String issuer, String subject, long ttlMillis) throws Exception {
        JWSSigner signer = new MACSigner(secret.getBytes(StandardCharsets.UTF_8));

        long now = System.currentTimeMillis();
        JWTClaimsSet claimsSet = new JWTClaimsSet.Builder()
                .subject(subject)
                .issuer(issuer)
                .issueTime(new Date(now))
                .expirationTime(new Date(now + ttlMillis))
                .claim("email", "john.doe@bank.com")
                .claim("role", "CUSTOMER")
                .build();

        SignedJWT signedJWT = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claimsSet);
        signedJWT.sign(signer);
        return signedJWT.serialize();
    }

    @Test
    @DisplayName("Valid token signed with user's secret should pass validation")
    void testValidTokenWithUserSecret() throws Exception {
        String token = createToken(USER_SECRET, ISSUER, "USR-10001", 900_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isTrue();
    }

    @Test
    @DisplayName("Token signed with different secret should be rejected")
    void testInvalidSecretRejected() throws Exception {
        String wrongSecret = "wrong-secret-key-that-is-at-least-256-bits-long-for-hmac-sha-256-test-validation";
        String token = createToken(wrongSecret, ISSUER, "USR-10001", 900_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isFalse();
    }

    @Test
    @DisplayName("Expired token should be rejected")
    void testExpiredTokenRejected() throws Exception {
        String token = createToken(USER_SECRET, ISSUER, "USR-10001", -10_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isFalse();
    }

    @Test
    @DisplayName("Token with unknown issuer should be rejected")
    void testUnknownIssuerRejected() throws Exception {
        String token = createToken(USER_SECRET, "malicious-unknown-service", "USR-10001", 900_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isFalse();
    }

    @Test
    @DisplayName("Token with blank subject should be rejected")
    void testBlankSubjectRejected() throws Exception {
        String token = createToken(USER_SECRET, ISSUER, "", 900_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isFalse();
    }

    @Test
    @DisplayName("Token with account-service issuer alias should pass validation")
    void testAccountServiceIssuerAccepted() throws Exception {
        String token = createToken(USER_SECRET, "account-service", "USR-10002", 900_000);
        boolean isValid = validator.validate(token);
        assertThat(isValid).isTrue();
    }
}
