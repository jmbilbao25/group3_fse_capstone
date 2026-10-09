package com.fse.banking.account.storage;

import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.sas.BlobSasPermission;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import com.azure.storage.common.sas.SasProtocol;
import com.fse.banking.account.dto.KycUploadIntentResponse;
import com.fse.banking.account.dto.KycUploadSlot;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@Slf4j
@Service
public class AzuriteBlobStorageService implements BlobStorageAdapter {

    @Value("${azure.storage.connection-string:DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;}")
    private String connectionString;

    @Value("${azure.storage.container-name:kyc-vault}")
    private String containerName;

    @Value("${azure.storage.sas-expiry-seconds:300}")
    private int sasExpirySeconds;

    @Value("${azure.storage.public-endpoint:}")
    private String publicEndpoint;

    private BlobContainerClient containerClient;

    @PostConstruct
    public void init() {
        try {
            BlobServiceClient serviceClient = new BlobServiceClientBuilder()
                    .connectionString(connectionString)
                    .buildClient();
            this.containerClient = serviceClient.getBlobContainerClient(containerName);
            if (!containerClient.exists()) {
                containerClient.create();
                log.info("Initialized Azure Blob storage container: {}", containerName);
            }
            try {
                com.azure.storage.blob.models.BlobCorsRule corsRule = new com.azure.storage.blob.models.BlobCorsRule()
                        .setAllowedOrigins("*")
                        .setAllowedMethods("GET,POST,PUT,DELETE,OPTIONS,HEAD,PATCH")
                        .setAllowedHeaders("*")
                        .setExposedHeaders("*")
                        .setMaxAgeInSeconds(3600);
                com.azure.storage.blob.models.BlobServiceProperties properties = serviceClient.getProperties();
                properties.setCors(java.util.List.of(corsRule));
                serviceClient.setProperties(properties);
                log.info("Configured CORS rule for Azurite/Azure Blob Storage");
            } catch (Exception ce) {
                log.debug("CORS initialization skipped: {}", ce.getMessage());
            }
        } catch (Exception e) {
            log.warn("Could not immediately connect to Blob Storage during startup: {}", e.getMessage());
        }
    }

    private synchronized BlobContainerClient getContainerClient() {
        if (this.containerClient == null) {
            BlobServiceClient serviceClient = new BlobServiceClientBuilder()
                    .connectionString(connectionString)
                    .buildClient();
            this.containerClient = serviceClient.getBlobContainerClient(containerName);
            if (!this.containerClient.exists()) {
                this.containerClient.create();
            }
        }
        return this.containerClient;
    }

    @Override
    public KycUploadIntentResponse generateUploadIntent(String userId, String idType, boolean requireBack) {
        String submissionId = "KYC-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10).toUpperCase();
        String basePath = "users/" + userId + "/" + submissionId;

        KycUploadSlot frontSlot = createUploadSlot("id_front", basePath + "/id_front.jpg");
        KycUploadSlot backSlot = requireBack ? createUploadSlot("id_back", basePath + "/id_back.jpg") : null;
        KycUploadSlot selfieSlot = createUploadSlot("selfie", basePath + "/selfie.jpg");

        return KycUploadIntentResponse.builder()
                .submissionId(submissionId)
                .containerName(containerName)
                .expiresInSeconds(sasExpirySeconds)
                .frontSlot(frontSlot)
                .backSlot(backSlot)
                .selfieSlot(selfieSlot)
                .build();
    }

    @Override
    public boolean verifyBlobExists(String blobPath) {
        try {
            BlobClient blobClient = getContainerClient().getBlobClient(blobPath);
            return blobClient.exists();
        } catch (Exception e) {
            log.error("Failed to verify blob existence for path: {}", blobPath, e);
            return false;
        }
    }

    @Override
    public String generateReadSasUri(String blobPath, Duration ttl) {
        BlobClient blobClient = getContainerClient().getBlobClient(blobPath);
        BlobSasPermission permission = new BlobSasPermission().setReadPermission(true);
        BlobServiceSasSignatureValues values = new BlobServiceSasSignatureValues(
                OffsetDateTime.now(ZoneOffset.UTC).plus(ttl),
                permission
        ).setProtocol(SasProtocol.HTTPS_HTTP);

        String sasToken = blobClient.generateSas(values);
        return formatUrl(blobClient.getBlobUrl() + "?" + sasToken);
    }

    private KycUploadSlot createUploadSlot(String slotName, String blobPath) {
        BlobClient blobClient = getContainerClient().getBlobClient(blobPath);
        BlobSasPermission permission = new BlobSasPermission()
                .setCreatePermission(true)
                .setWritePermission(true);

        BlobServiceSasSignatureValues values = new BlobServiceSasSignatureValues(
                OffsetDateTime.now(ZoneOffset.UTC).plusSeconds(sasExpirySeconds),
                permission
        ).setProtocol(SasProtocol.HTTPS_HTTP);

        String sasToken = blobClient.generateSas(values);
        String finalUrl = formatUrl(blobClient.getBlobUrl() + "?" + sasToken);

        return KycUploadSlot.builder()
                .slotName(slotName)
                .blobPath(blobPath)
                .uploadUrl(finalUrl)
                .httpMethod("PUT")
                .build();
    }

    private String formatUrl(String rawUrl) {
        if (publicEndpoint != null && !publicEndpoint.isBlank()) {
            // Replace internal docker or localhost endpoint prefix with custom public endpoint
            String[] internalHosts = {
                "http://127.0.0.1:10000/devstoreaccount1",
                "http://localhost:10000/devstoreaccount1",
                "http://azurite-storage:10000/devstoreaccount1",
                "http://azurite:10000/devstoreaccount1"
            };
            for (String host : internalHosts) {
                if (rawUrl.startsWith(host)) {
                    return rawUrl.replace(host, publicEndpoint);
                }
            }
        }
        return rawUrl;
    }
}
