package com.fse.banking.common.exception;

public class LockedUserException extends BankingException {

    public LockedUserException(String detail) {
        super(403, "https://api.banking.capstone/errors/account-locked", "User Account Locked", detail);
    }
}
