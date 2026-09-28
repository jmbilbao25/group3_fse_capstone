package com.fse.banking.common.exception;

import com.fse.banking.common.dto.InvalidParam;
import lombok.Getter;

import java.util.List;

@Getter
public class ValidationException extends BankingException {

    private final List<InvalidParam> invalidParams;

    public ValidationException(String detail, List<InvalidParam> invalidParams) {
        super(400, "https://api.banking.capstone/errors/validation-failed", "Bad Request", detail);
        this.invalidParams = invalidParams;
    }
}
