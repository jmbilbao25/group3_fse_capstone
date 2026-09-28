package com.fse.banking.account.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtProvider {

    @Value("${jwt.secret:c3VwZXItc2VjcmV0LWtleS1mb3ItZnNlLWNhcHN0b25lLWJhbmtpbmctcGxhdGZvcm0tMjAyNi0xMjM0NTY3ODkwMTI=}")
    private String secret;

    @Value("${jwt.access-token-expiration-seconds:900}")
    private long accessTokenExpirationSeconds;

    @Value("${jwt.issuer:fse-banking-account-service}")
    private String issuer;

    private SecretKey key;

    @PostConstruct
    public void init() {
        byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
        this.key = Keys.hmacShaKeyFor(keyBytes);
    }

    public String generateAccessToken(String userId, String email, String role, String jti) {
        Instant now = Instant.now();
        Instant expiry = now.plusSeconds(accessTokenExpirationSeconds);

        if (jti == null) {
            jti = UUID.randomUUID().toString();
        }

        return Jwts.builder()
                .header().type("JWT").and()
                .subject(userId)
                .claim("email", email)
                .claim("role", role)
                .id(jti)
                .issuer(issuer)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(key)
                .compact();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public Claims getClaims(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String getUserId(String token) {
        return getClaims(token).getSubject();
    }

    public String getEmail(String token) {
        return getClaims(token).get("email", String.class);
    }

    public String getRole(String token) {
        return getClaims(token).get("role", String.class);
    }

    public String getJti(String token) {
        return getClaims(token).getId();
    }

    public long getRemainingTtlSeconds(String token) {
        Date expiration = getClaims(token).getExpiration();
        long diff = (expiration.getTime() - System.currentTimeMillis()) / 1000;
        return Math.max(0, diff);
    }

    public long getAccessTokenExpirationSeconds() {
        return accessTokenExpirationSeconds;
    }
}
