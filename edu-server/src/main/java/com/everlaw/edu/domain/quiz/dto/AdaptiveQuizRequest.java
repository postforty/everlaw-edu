package com.everlaw.edu.domain.quiz.dto;

import jakarta.validation.constraints.NotBlank;

public record AdaptiveQuizRequest(
        @NotBlank(message = "Law reference is required")
        String lawReference
) {
}
