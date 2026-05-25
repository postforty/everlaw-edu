package com.everlaw.edu.domain.progress.dto;

public record ProgressQuizSubmitResponse(
        boolean isCorrect,
        int answerIndex,
        String explanation,
        boolean isGraduated,
        double weaknessScore
) {
}
