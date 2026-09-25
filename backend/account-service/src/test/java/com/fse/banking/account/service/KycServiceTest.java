package com.fse.banking.account.service;

import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ResourceNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class KycServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private KycService kycService;

    private UserEntity user;

    @BeforeEach
    void setUp() {
        user = UserEntity.builder()
                .userId("USR-100001")
                .firstName("Juan")
                .lastName("Dela Cruz")
                .email("juan.delacruz@example.ph")
                .phoneNumber("+639171234567")
                .dob(LocalDate.of(1990, 5, 15))
                .governmentId("PASSPORT-P9876543A")
                .role(UserRole.CUSTOMER)
                .status(UserStatus.ACTIVE)
                .build();
    }

    @Test
    @DisplayName("Should list all customer profiles for KYC review")
    void testListPendingKyc() {
        when(userRepository.findByRole(UserRole.CUSTOMER)).thenReturn(List.of(user));

        List<KycProfileResponse> results = kycService.listPendingKyc();

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getUserId()).isEqualTo("USR-100001");
        assertThat(results.get(0).getEmail()).isEqualTo("juan.delacruz@example.ph");
    }

    @Test
    @DisplayName("Should retrieve individual KYC profile by user ID")
    void testGetKycProfile() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));

        KycProfileResponse profile = kycService.getKycProfile("USR-100001");

        assertThat(profile).isNotNull();
        assertThat(profile.getUserId()).isEqualTo("USR-100001");
        assertThat(profile.getGovernmentId()).isEqualTo("PASSPORT-P9876543A");
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when profile not found")
    void testGetKycProfileNotFound() {
        when(userRepository.findById("USR-999999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> kycService.getKycProfile("USR-999999"))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Customer profile not found for user: USR-999999");
    }

    @Test
    @DisplayName("Should approve customer KYC profile and set status to ACTIVE")
    void testApproveKyc() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycProfileResponse response = kycService.approveKyc("USR-100001", "ADMIN-01");

        assertThat(response.getStatus()).isEqualTo("ACTIVE");
        verify(userRepository).save(user);
    }

    @Test
    @DisplayName("Should reject customer KYC profile and set status to SUSPENDED")
    void testRejectKyc() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycProfileResponse response = kycService.rejectKyc("USR-100001", "ADMIN-01", "Invalid ID photo");

        assertThat(response.getStatus()).isEqualTo("SUSPENDED");
        verify(userRepository).save(user);
    }
}
