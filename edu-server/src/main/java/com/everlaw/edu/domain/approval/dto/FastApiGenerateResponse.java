package com.everlaw.edu.domain.approval.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record FastApiGenerateResponse(
        @JsonProperty("law_id")
        String lawId,

        @JsonProperty("analysis_result")
        AnalysisResult analysisResult,

        @JsonProperty("validation_result")
        ValidationResult validationResult,

        @JsonProperty("markdown_report")
        String markdownReport,

        @JsonProperty("status")
        String status
) {
    public record AnalysisResult(
            @JsonProperty("lesson_id")
            int lessonId,

            @JsonProperty("title")
            String title,

            @JsonProperty("category")
            String category,

            @JsonProperty("law_reference")
            String lawReference,

            @JsonProperty("content_markdown")
            String contentMarkdown,

            @JsonProperty("quiz_proposed")
            String quizProposed
    ) {}

    public record ValidationResult(
            @JsonProperty("is_valid")
            boolean isValid,

            @JsonProperty("hallucination_score")
            Double hallucinationScore,

            @JsonProperty("validation_details")
            String validationDetails,

            @JsonProperty("warning_flag")
            boolean warningFlag
    ) {}
}
