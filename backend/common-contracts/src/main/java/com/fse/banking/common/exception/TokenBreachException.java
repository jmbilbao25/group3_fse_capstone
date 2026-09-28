package com.fse.banking.common.exception;

public class TokenBreachException extends BankingException {

    public TokenBreachException(String detail) {
        super(401, "https://api.retailbank.ph/errors/token-breach-detected", "Token Replay Breach Detected", detail);
    }
}
