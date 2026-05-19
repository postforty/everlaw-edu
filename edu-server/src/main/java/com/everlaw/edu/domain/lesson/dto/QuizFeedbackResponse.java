package com.everlaw.edu.domain.lesson.dto;

public record QuizFeedbackResponse(
        Long lessonId,
        String selectedAnswer,
        boolean correct,
        String explanation
) {
}
