package com.everlaw.edu.domain.quiz.service;

import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import com.everlaw.edu.domain.quiz.dto.AdaptiveQuizRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdaptiveQuizService {

    private final QuizBankRepository quizBankRepository;
    private final RestClient aiEngineRestClient;

    public Map<String, Object> generateAdaptiveQuiz(AdaptiveQuizRequest request) {
        log.info("🚀 [Adaptive Quiz] Requesting adaptive quiz for Law Reference: {}", request.lawReference());

        // 1. Fetch previous questions for this law reference to exclude them
        List<QuizBank> previousQuizzes = quizBankRepository.findAll().stream()
                .filter(q -> request.lawReference().equals(q.getLawReference()))
                .collect(Collectors.toList());

        List<String> previousQuestions = previousQuizzes.stream()
                .map(QuizBank::getQuestion)
                .collect(Collectors.toList());

        // 2. Prepare payload for FastAPI
        Map<String, Object> payload = Map.of(
                "law_reference", request.lawReference(),
                "previous_questions", previousQuestions
        );

        // 3. Call FastAPI to generate new quiz
        try {
            log.info("📡 [AI Engine Call] Sending request to FastAPI /api/v1/adaptive-quiz...");
            
            @SuppressWarnings("unchecked")
            Map<String, Object> response = aiEngineRestClient.post()
                    .uri("/api/v1/adaptive-quiz")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .body(Map.class);

            log.info("✅ [AI Engine Response] Successfully received adaptive quiz from AI Engine.");
            
            // Just return the proxy response directly to the client
            return response;

        } catch (Exception e) {
            log.error("❌ [Adaptive Quiz Failed] Failed to generate adaptive quiz", e);
            throw new RuntimeException("Failed to generate adaptive quiz from AI Engine", e);
        }
    }
}
