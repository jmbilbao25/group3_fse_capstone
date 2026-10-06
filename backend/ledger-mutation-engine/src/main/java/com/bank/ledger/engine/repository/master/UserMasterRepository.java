package com.bank.ledger.engine.repository.master;

import com.bank.ledger.engine.entity.master.UserMaster;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserMasterRepository extends JpaRepository<UserMaster, String> {
    Optional<UserMaster> findByEmail(String email);
}
