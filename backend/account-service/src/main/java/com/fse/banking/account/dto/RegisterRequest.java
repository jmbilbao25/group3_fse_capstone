package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    private String password;

    @NotBlank(message = "First name is required")
    @JsonProperty("first_name")
    private String firstName;

    @NotBlank(message = "Last name is required")
    @JsonProperty("last_name")
    private String lastName;

    @JsonProperty("middle_name")
    private String middleName;

    @NotNull(message = "Date of birth is required")
    @JsonProperty("date_of_birth")
    private LocalDate dateOfBirth;

    @NotBlank(message = "Phone number is required")
    @JsonProperty("phone_number")
    private String phoneNumber;

    @NotBlank(message = "Address line is required")
    @JsonProperty("address_line")
    private String addressLine;

    @NotBlank(message = "Government ID type is required")
    @JsonProperty("government_id_type")
    private String governmentIdType;

    @NotBlank(message = "Government ID number is required")
    @JsonProperty("government_id_number")
    private String governmentIdNumber;
}
