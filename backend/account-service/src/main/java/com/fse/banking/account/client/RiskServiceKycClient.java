package com.fse.banking.account.client;

import com.fse.banking.account.client.dto.KycEvaluationClientRequest;
import com.fse.banking.account.client.dto.KycEvaluationClientResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Slf4j
@Component
public class RiskServiceKycClient implements KycClient {

    @Value("${app.services.risk-service.url:http://localhost:8084}")
    private String riskServiceUrl;

    private final RestTemplate restTemplate;

    public RiskServiceKycClient() {
        org.springframework.http.client.SimpleClientHttpRequestFactory factory =
                new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setBufferRequestBody(true);
        factory.setConnectTimeout(5000);
        factory.setReadTimeout(15000);
        this.restTemplate = new RestTemplate(factory);
    }

    public RiskServiceKycClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @Override
    public KycEvaluationClientResponse evaluateKyc(KycEvaluationClientRequest request) {
        String url = riskServiceUrl + "/api/v1/kyc/evaluate";
        log.info("Dispatching e-KYC evaluation to Laya Vision Engine at {}", url);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<KycEvaluationClientRequest> entity = new HttpEntity<>(request, headers);

        try {
            ResponseEntity<KycEvaluationClientResponse> response = restTemplate.postForEntity(
                    url,
                    entity,
                    KycEvaluationClientResponse.class
            );
            return response.getBody();
        } catch (Exception e) {
            log.error("Failed to evaluate KYC via Laya Risk Service: {}", e.getMessage(), e);
            throw new RuntimeException("Laya KYC Vision Engine evaluation failed: " + e.getMessage(), e);
        }
    }
}
