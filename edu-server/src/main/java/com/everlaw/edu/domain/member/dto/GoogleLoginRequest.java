package com.everlaw.edu.domain.member.dto;

import com.everlaw.edu.domain.member.Role;
import jakarta.validation.constraints.NotBlank;

public record GoogleLoginRequest(
        @NotBlank(message = "idToken is required")
        String idToken,
        
        Role role,
        
        String jobCategory
) {
}
