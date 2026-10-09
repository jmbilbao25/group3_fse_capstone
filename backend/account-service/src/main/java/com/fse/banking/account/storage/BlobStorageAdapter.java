package com.fse.banking.account.storage;

import com.fse.banking.account.dto.KycUploadIntentResponse;

import java.time.Duration;

public interface BlobStorageAdapter {

    /**
     * Generates time-bounded pre-signed SAS upload URLs for identity verification slots.
     */
    KycUploadIntentResponse generateUploadIntent(String userId, String idType, boolean requireBack);

    /**
     * Checks if a blob exists in the KYC vault container.
     */
    boolean verifyBlobExists(String blobPath);

    /**
     * Generates a read-only SAS URI for internal or verification review.
     */
    String generateReadSasUri(String blobPath, Duration ttl);
}
