package com.bank.ledger.gateway.security;

import com.nimbusds.jose.crypto.MACVerifier;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtTokenValidator {

    private static final String SECRET =
            "banking-system-capstone-secret-key";

    public boolean validate(String token) {

        try {

            SignedJWT jwt = SignedJWT.parse(token); //Parse JWT

            boolean validSignature = jwt.verify(new MACVerifier(SECRET) ); //validator

            if (!validSignature) {
                return false;
            }

            Date expiration = jwt.getJWTClaimsSet().getExpirationTime(); //Current Time > Expiration Time

            if (expiration == null ||
                    expiration.before(new Date())) {
                return false;
            }

            String issuer = jwt.getJWTClaimsSet().getIssuer(); //prevents token from unknown services

            if (!"account-service".equals(issuer)) {
                return false;
            }

            String subject = jwt.getJWTClaimsSet().getSubject(); //check the subject (user ID)

            return subject != null
                    && !subject.isBlank();

        } catch (Exception e) {
            return false;
        }
    }
}