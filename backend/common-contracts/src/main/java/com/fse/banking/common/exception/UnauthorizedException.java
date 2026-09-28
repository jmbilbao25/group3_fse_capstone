package com.fse.banking.common.exception;

public class UnauthorizedException extends BankingException {

    public UnauthorizedException(String detail) {
        super(401, "https://api.banking.capstone/errors/unauthorized", "Unauthorized", detail);
    }
}
