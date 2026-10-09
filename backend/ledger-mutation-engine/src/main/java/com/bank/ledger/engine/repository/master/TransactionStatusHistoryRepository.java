package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.TransactionStatusHistoryMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TransactionStatusHistoryRepository extends JpaRepository<TransactionStatusHistoryMaster, String> {
    List<TransactionStatusHistoryMaster> findByTransactionIdOrderByChangedAtAsc(String transactionId);
}