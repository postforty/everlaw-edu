package com.everlaw.edu.domain.chatbot;

import com.everlaw.edu.domain.chatbot.dto.ChatRequestDto;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Service
public class ChatbotService {

    private final RestClient aiEngineRestClient;

    public ChatbotService(@Qualifier("aiEngineRestClient") RestClient aiEngineRestClient) {
        this.aiEngineRestClient = aiEngineRestClient;
    }

    public Map<String, Object> getChatResponse(ChatRequestDto request) {
        return aiEngineRestClient.post()
                .uri("/api/v1/chat")
                .body(request)
                .retrieve()
                .body(Map.class);
    }
}
