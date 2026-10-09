package com.fse.banking.account.kyc;

import java.util.List;
import java.util.Optional;

/** Latest KYC review per customer. */
public interface KycReviewStore {
    void save(KycReview review);

    Optional<KycReview> find(String userId);

    List<KycReview> findAll();
}
