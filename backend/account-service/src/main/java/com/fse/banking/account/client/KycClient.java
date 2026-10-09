package com.fse.banking.account.client;

import com.fse.banking.account.client.dto.KycEvaluationClientRequest;
import com.fse.banking.account.client.dto.KycEvaluationClientResponse;

public interface KycClient {
    KycEvaluationClientResponse evaluateKyc(KycEvaluationClientRequest request);
}
