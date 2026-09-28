package com.fse.banking.account.repository;

import com.fse.banking.account.model.UserEntity;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<UserEntity, String> {

    Optional<UserEntity> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByPhoneNumber(String phoneNumber);

    boolean existsByGovernmentId(String governmentId);

    List<UserEntity> findByStatus(UserStatus status);

    List<UserEntity> findByRole(UserRole role);
}
