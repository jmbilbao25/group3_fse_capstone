package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.ReversalRequestMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReversalRequestRepository extends JpaRepository<ReversalRequestMaster, String> {
    List<ReversalRequestMaster> findAllByOrderByCreatedAtDesc();
    List<ReversalRequestMaster> findByStatusOrderByCreatedAtDesc(String status);
}