package com.everlaw.edu.domain.approval.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record FastApiLawChangeRequest(
        @JsonProperty("law_id")
        String lawId,

        @JsonProperty("content")
        String content,

        @JsonProperty("previous_questions")
        java.util.List<String> previousQuestions
) {
}
