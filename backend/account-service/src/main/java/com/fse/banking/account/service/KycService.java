package com.fse.banking.account.service;

import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class KycService {

    private final UserRepository userRepository;

    public List<KycProfileResponse> listPendingKyc() {
        return userRepository.findByRole(UserRole.CUSTOMER)
                .stream()
                .map(this::toProfileResponse)
                .toList();
    }

    public KycProfileResponse getKycProfile(String userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));
        return toProfileResponse(user);
    }

    @Transactional
    public KycProfileResponse approveKyc(String userId, String reviewerId) {
        log.info("Approving KYC for user {} by reviewer {}", userId, reviewerId);
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        user.setStatus(UserStatus.ACTIVE);
        UserEntity updated = userRepository.save(user);
        return toProfileResponse(updated);
    }

    @Transactional
    public KycProfileResponse rejectKyc(String userId, String reviewerId, String reason) {
        log.info("Rejecting KYC for user {} by reviewer {} with reason: {}", userId, reviewerId, reason);
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        user.setStatus(UserStatus.SUSPENDED);
        UserEntity updated = userRepository.save(user);
        return toProfileResponse(updated);
    }

    private KycProfileResponse toProfileResponse(UserEntity user) {
        return KycProfileResponse.builder()
                .userId(user.getUserId())
                .firstName(user.getFirstName())
                .middleName(user.getMiddleName())
                .lastName(user.getLastName())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .dob(user.getDob())
                .governmentId(user.getGovernmentId())
                .role(user.getRole().name())
                .status(user.getStatus().name())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
