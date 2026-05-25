package com.everlaw.edu.domain.chatbot.dto;

import java.util.List;
import java.util.Map;

public record ChatRequestDto(
        String message,
        String context,
        List<Map<String, Object>> history
) {
}
