package com.everlaw.edu.domain.progress.dto;

import jakarta.validation.constraints.NotNull;

public record ProgressQuizSubmitRequest(
        @NotNull(message = "Quiz ID is required")
        Long quizId,

        @NotNull(message = "Selected index is required")
        Integer selectedIndex
) {
}
