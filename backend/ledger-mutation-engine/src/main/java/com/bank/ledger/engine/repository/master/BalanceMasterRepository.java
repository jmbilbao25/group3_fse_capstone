package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.BalanceMaster;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BalanceMasterRepository extends JpaRepository<BalanceMaster, String> {

    /**
     * Banking Critical: Acquires an exclusive row-level lock (SELECT ... FOR UPDATE)
     * Blocks all other transactions from reading/writing this account balance until committed.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM BalanceMaster b WHERE b.accountId = :accountId")
    Optional<BalanceMaster> findByAccountIdWithLock(@Param("accountId") String accountId);
}