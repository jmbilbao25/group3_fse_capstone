package com.fse.banking.common.exception;

import lombok.Getter;

@Getter
public abstract class BankingException extends RuntimeException {

    private final int status;
    private final String errorType;
    private final String title;

    protected BankingException(int status, String errorType, String title, String detail) {
        super(detail);
        this.status = status;
        this.errorType = errorType;
        this.title = title;
    }

    protected BankingException(int status, String errorType, String title, String detail, Throwable cause) {
        super(detail, cause);
        this.status = status;
        this.errorType = errorType;
        this.title = title;
    }
}
