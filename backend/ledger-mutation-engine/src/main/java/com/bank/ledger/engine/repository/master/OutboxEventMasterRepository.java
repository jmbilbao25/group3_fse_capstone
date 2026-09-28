package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.OutboxEventMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OutboxEventMasterRepository extends JpaRepository<OutboxEventMaster, String> {

    /**
     * Fetches pending events in FIFO order for the Outbox worker to publish.
     */
    List<OutboxEventMaster> findTop50ByStatusOrderByCreatedAtAsc(String status);

    List<OutboxEventMaster> findByStatusOrderByCreatedAtAsc(String status);
}