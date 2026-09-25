package com.fse.banking.common.exception;

public class ConflictException extends BankingException {

    public ConflictException(String detail) {
        super(409, "https://api.banking.capstone/errors/conflict", "Resource Conflict", detail);
    }
}
