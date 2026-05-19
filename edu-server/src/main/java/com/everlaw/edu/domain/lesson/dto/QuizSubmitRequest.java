package com.everlaw.edu.domain.lesson.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record QuizSubmitRequest(
        @NotNull(message = "Lesson ID is required")
        Long lessonId,

        @NotBlank(message = "Selected answer is required")
        String selectedAnswer
) {
}
