package com.everlaw.edu.domain.progress.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AdaptiveQuizSubmitRequest(
        @NotBlank(message = "Law reference is required")
        String lawReference,

        @NotNull(message = "isCorrect is required")
        Boolean isCorrect
) {
}
