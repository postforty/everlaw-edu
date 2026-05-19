package com.everlaw.edu.domain.member.dto;

import com.everlaw.edu.domain.member.Role;

public record AuthResponse(
        String token,
        String email,
        Role role,
        String jobCategory
) {
}
