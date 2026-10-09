package com.fse.banking.account.exception;

import com.fse.banking.common.exception.BankingException;

public class TooManyRequestsException extends BankingException {
    public TooManyRequestsException(String detail) {
        super(429, "https://api.banking.capstone/errors/too-many-requests", "Too Many Requests", detail);
    }
}
