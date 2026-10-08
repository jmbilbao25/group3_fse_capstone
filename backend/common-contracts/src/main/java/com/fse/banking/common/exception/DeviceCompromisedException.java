package com.fse.banking.common.exception;

public class DeviceCompromisedException extends BankingException {

    public DeviceCompromisedException(String detail) {
        super(
            403,
            "https://api.banking.capstone/errors/device-compromised",
            "Device Integrity Violation",
            detail != null ? detail : "This application cannot be run on a compromised or unverified mobile device."
        );
    }
}
