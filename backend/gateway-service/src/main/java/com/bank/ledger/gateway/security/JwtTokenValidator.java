package com.bank.ledger.gateway.security;

import com.nimbusds.jose.crypto.MACVerifier;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
public class JwtTokenValidator {

    @Value("${jwt.secret:c3VwZXItc2VjcmV0LWtleS1mb3ItZnNlLWNhcHN0b25lLWJhbmtpbmctcGxhdGZvcm0tMjAyNi0xMjM0NTY3ODkwMTI=}")
    private String secret;

    @Value("${jwt.issuer:fse-banking-account-service}")
    private String issuer;

    public JwtTokenValidator() {
    }

    public JwtTokenValidator(String secret, String issuer) {
        this.secret = secret;
        this.issuer = issuer;
    }

    public boolean validate(String token) {

        try {

            SignedJWT jwt = SignedJWT.parse(token); // Parse JWT

            byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
            boolean validSignature = jwt.verify(new MACVerifier(keyBytes)); // validator with configured secret

            if (!validSignature) {
                return false;
            }

            Date expiration = jwt.getJWTClaimsSet().getExpirationTime(); // Current Time > Expiration Time

            if (expiration == null || expiration.before(new Date())) {
                return false;
            }

            String tokenIssuer = jwt.getJWTClaimsSet().getIssuer(); // prevents token from unknown services

            if (tokenIssuer != null 
                    && !tokenIssuer.equals(issuer) 
                    && !"fse-banking-account-service".equals(tokenIssuer) 
                    && !"account-service".equals(tokenIssuer)) {
                return false;
            }

            String subject = jwt.getJWTClaimsSet().getSubject(); // check the subject (user ID)

            return subject != null && !subject.isBlank();

        } catch (Exception e) {
            System.err.println("[GATEWAY JWT ERROR] " + e.getClass().getName() + ": " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
}