package com.everlaw.edu.domain.approval.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ApprovalActionRequest(
        @NotNull(message = "Action approved status must be specified")
        Boolean approved,

        @NotBlank(message = "Admin email is required")
        @Email(message = "Invalid email format")
        String adminEmail
) {
}
