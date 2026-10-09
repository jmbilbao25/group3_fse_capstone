package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.TransactionMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionMasterRepository extends JpaRepository<TransactionMaster, String> {
    List<TransactionMaster> findByStatus(String status);
    List<TransactionMaster> findAllByOrderByCreatedAtDesc();
    Optional<TransactionMaster> findTopByFromAccountIdAndLatitudeIsNotNullOrderByCreatedAtDesc(String fromAccountId);

    /** Outgoing transfers that count against a tier limit: settled or still held. */
    @Query("select coalesce(sum(t.amount), 0) from TransactionMaster t "
            + "where t.fromAccountId in :accountIds and t.type = 'TRANSFER' "
            + "and t.status in ('COMMITTED', 'PENDING_APPROVAL') and t.createdAt >= :since")
    BigDecimal sumOutgoingSince(@Param("accountIds") Collection<String> accountIds, @Param("since") Instant since);
}
