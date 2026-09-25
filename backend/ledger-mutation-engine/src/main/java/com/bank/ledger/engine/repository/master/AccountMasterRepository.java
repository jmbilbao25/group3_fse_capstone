package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.AccountMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AccountMasterRepository extends JpaRepository<AccountMaster, String> {
}