package com.fse.banking.common.exception;

public class ForbiddenException extends BankingException {

    public ForbiddenException(String detail) {
        super(403, "https://api.banking.capstone/errors/forbidden", "Forbidden", detail);
    }
}
