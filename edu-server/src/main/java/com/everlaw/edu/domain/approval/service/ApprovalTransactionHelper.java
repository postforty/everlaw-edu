package com.everlaw.edu.domain.approval.service;

import com.everlaw.edu.domain.approval.ApprovalRequest;
import com.everlaw.edu.domain.approval.ApprovalRequestRepository;
import com.everlaw.edu.domain.approval.ApprovalStatus;
import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse;
import com.everlaw.edu.domain.approval.dto.GenerateTriggerRequest;
import com.everlaw.edu.domain.curriculum.Curriculum;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class ApprovalTransactionHelper {

    private final ApprovalRequestRepository approvalRequestRepository;
    private final ObjectMapper objectMapper;

    /**
     * AI 엔진의 정상 응답 데이터를 트랜잭션 범위 내에서 안전하게 PENDING 상태의 승인 대기열로 적재합니다.
     */
    @Transactional
    public void saveProposedContent(Curriculum curriculum, GenerateTriggerRequest request, FastApiGenerateResponse response) {
        var analysis = response.analysisResult();
        var validation = response.validationResult();

        // 퀴즈 페이로드 직렬화
        String quizPayload = "";
        try {
            quizPayload = objectMapper.writeValueAsString(Map.of(
                "question", analysis.quizQuestion(),
                "options", analysis.quizOptions(),
                "answerIndex", analysis.quizAnswerIndex(),
                "hint", analysis.quizHint(),
                "explanation", analysis.quizExplanation()
            ));
        } catch (Exception e) {
            log.error("Failed to serialize quiz data", e);
        }

        ApprovalRequest approvalRequest = ApprovalRequest.builder()
                .curriculum(curriculum)
                .title(analysis.title())
                .lawReference(response.lawId())
                .lawReferenceBody(request.lawContent())
                .aiGeneratedMarkdown(response.markdownReport())
                .quizPayload(quizPayload)
                .validationDetails(validation.validationDetails())
                .hallucinationScore(validation.hallucinationScore())
                .status(ApprovalStatus.PENDING)
                .build();
        log.info("📥 [Approval Queue] Created new AI generated content into approval request queue for LawReference: {}", response.lawId());

        approvalRequestRepository.save(approvalRequest);
    }

    /**
     * AI 엔진 예외 시 비즈니스 무중단을 달성하기 위해 PoC Fallback 데이터를 대기열에 탑재합니다.
     */
    @Transactional
    public void saveFallbackContent(Curriculum curriculum, GenerateTriggerRequest request, Exception ex) {
        String fallbackTitle = "Fallback: " + request.lawId() + " 규정 강의";
        String fallbackMarkdown = """
                # [자동 생산 장애 대응 폴백 교안]
                본 교안은 AI 엔진 서비스 예외로 인해 생성된 긴급 대체 교안입니다.
                
                ### 원천 법령 ID
                """ + request.lawId() + "\n\n### 법령 원본 본문\n" + request.lawContent();
        
        ApprovalRequest approvalRequest = ApprovalRequest.builder()
                .curriculum(curriculum)
                .title(fallbackTitle)
                .lawReference(request.lawId())
                .lawReferenceBody(request.lawContent())
                .aiGeneratedMarkdown(fallbackMarkdown)
                .validationDetails("AI 엔진 통신 오류 발생 폴백 모드 적재: " + ex.getMessage())
                .hallucinationScore(0.99) // 위험도 적색 경보 부과
                .status(ApprovalStatus.PENDING)
                .build();

        approvalRequestRepository.save(approvalRequest);
        log.warn("⚠️ [Approval Queue - Fallback] Loaded fallback compliance content into queue due to infrastructure exception.");
    }

    @Transactional
    public void deletePendingRequests(String lawReference) {
        approvalRequestRepository.deleteByLawReferenceAndStatus(lawReference, ApprovalStatus.PENDING);
        log.info("🗑️ [Approval Queue] Deleted existing PENDING requests for LawReference: {}", lawReference);
    }
}
