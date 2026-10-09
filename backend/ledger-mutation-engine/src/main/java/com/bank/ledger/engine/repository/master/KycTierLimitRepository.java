package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.KycTierLimit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface KycTierLimitRepository extends JpaRepository<KycTierLimit, Integer> {
}
