package com.bank.ledger.notification.repository;

import com.bank.ledger.notification.entity.NotificationEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<NotificationEntity, String> {

    List<NotificationEntity> findByUserIdOrderBySentAtDesc(String userId);

    List<NotificationEntity> findTop50ByOrderBySentAtDesc();
}
