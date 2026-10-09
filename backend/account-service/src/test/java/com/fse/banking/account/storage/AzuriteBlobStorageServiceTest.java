package com.fse.banking.account.storage;

import com.fse.banking.account.dto.KycUploadIntentResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

class AzuriteBlobStorageServiceTest {

    @Test
    @DisplayName("Should generate upload intent with 300-second SAS slots and valid blob paths")
    void testGenerateUploadIntentSlots() {
        AzuriteBlobStorageService service = new AzuriteBlobStorageService();

        // Standard test connection string (Azurite dev account)
        String azuriteConnStr = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;";
        ReflectionTestUtils.setField(service, "connectionString", azuriteConnStr);
        ReflectionTestUtils.setField(service, "containerName", "kyc-vault");
        ReflectionTestUtils.setField(service, "sasExpirySeconds", 300);
        ReflectionTestUtils.setField(service, "publicEndpoint", "");

        KycUploadIntentResponse intent = service.generateUploadIntent("USR-999", "DRIVERS_LICENSE", true);

        assertThat(intent).isNotNull();
        assertThat(intent.getSubmissionId()).startsWith("KYC-");
        assertThat(intent.getContainerName()).isEqualTo("kyc-vault");
        assertThat(intent.getExpiresInSeconds()).isEqualTo(300);

        // Front Slot
        assertThat(intent.getFrontSlot()).isNotNull();
        assertThat(intent.getFrontSlot().getSlotName()).isEqualTo("id_front");
        assertThat(intent.getFrontSlot().getBlobPath()).contains("users/USR-999/" + intent.getSubmissionId() + "/id_front.jpg");
        assertThat(intent.getFrontSlot().getUploadUrl()).contains("sig=");
        assertThat(intent.getFrontSlot().getUploadUrl()).contains("sp=cw"); // create & write permissions
        assertThat(intent.getFrontSlot().getHttpMethod()).isEqualTo("PUT");

        // Back Slot
        assertThat(intent.getBackSlot()).isNotNull();
        assertThat(intent.getBackSlot().getSlotName()).isEqualTo("id_back");
        assertThat(intent.getBackSlot().getUploadUrl()).contains("sig=");

        // Selfie Slot
        assertThat(intent.getSelfieSlot()).isNotNull();
        assertThat(intent.getSelfieSlot().getSlotName()).isEqualTo("selfie");
        assertThat(intent.getSelfieSlot().getBlobPath()).contains("users/USR-999/" + intent.getSubmissionId() + "/selfie.jpg");
        assertThat(intent.getSelfieSlot().getUploadUrl()).contains("sig=");
    }

    @Test
    @DisplayName("Should omit back slot when requireBack is false (e.g. Passport)")
    void testGenerateUploadIntentWithoutBack() {
        AzuriteBlobStorageService service = new AzuriteBlobStorageService();

        String azuriteConnStr = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;";
        ReflectionTestUtils.setField(service, "connectionString", azuriteConnStr);
        ReflectionTestUtils.setField(service, "containerName", "kyc-vault");
        ReflectionTestUtils.setField(service, "sasExpirySeconds", 300);
        ReflectionTestUtils.setField(service, "publicEndpoint", "");

        KycUploadIntentResponse intent = service.generateUploadIntent("USR-999", "PASSPORT", false);

        assertThat(intent.getFrontSlot()).isNotNull();
        assertThat(intent.getBackSlot()).isNull();
        assertThat(intent.getSelfieSlot()).isNotNull();
    }
}
