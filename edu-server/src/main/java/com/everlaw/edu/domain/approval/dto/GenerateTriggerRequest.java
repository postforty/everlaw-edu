package com.everlaw.edu.domain.approval.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record GenerateTriggerRequest(
        Long curriculumId,

        @NotBlank(message = "Law ID is required")
        String lawId,

        @NotBlank(message = "Law Content is required")
        String lawContent
) {
}
