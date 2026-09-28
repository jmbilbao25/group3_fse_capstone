package com.fse.banking.common.exception;

public class ResourceNotFoundException extends BankingException {

    public ResourceNotFoundException(String detail) {
        super(404, "https://api.banking.capstone/errors/resource-not-found", "Resource Not Found", detail);
    }
}
