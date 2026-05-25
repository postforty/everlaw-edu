package com.everlaw.edu.domain.approval.dto;

public record SourceLawResponse(
        String lawId,
        String lawName,
        String article,
        String content,
        boolean isGenerated
) {
}
