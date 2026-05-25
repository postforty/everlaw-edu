package com.everlaw.edu.domain.chatbot;

import com.everlaw.edu.domain.chatbot.dto.ChatRequestDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/chat")
@RequiredArgsConstructor
public class ChatbotController {

    private final ChatbotService chatbotService;

    @PostMapping
    public ResponseEntity<Map<String, Object>> chatWithAi(@RequestBody ChatRequestDto request) {
        Map<String, Object> response = chatbotService.getChatResponse(request);
        return ResponseEntity.ok(response);
    }
}
