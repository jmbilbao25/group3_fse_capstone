package com.fse.banking.account.repository;

import com.fse.banking.account.model.BalanceMasterEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BalanceMasterRepository extends JpaRepository<BalanceMasterEntity, String> {

    Optional<BalanceMasterEntity> findByAccountId(String accountId);
}
