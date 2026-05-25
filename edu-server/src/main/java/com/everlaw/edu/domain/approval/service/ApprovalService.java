package com.everlaw.edu.domain.approval.service;

import com.everlaw.edu.domain.approval.ApprovalRequest;
import com.everlaw.edu.domain.approval.ApprovalRequestRepository;
import com.everlaw.edu.domain.approval.ApprovalStatus;
import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse;
import com.everlaw.edu.domain.approval.dto.FastApiLawChangeRequest;
import com.everlaw.edu.domain.approval.dto.GenerateTriggerRequest;
import com.everlaw.edu.domain.approval.event.ContentEventPublisher;
import com.everlaw.edu.domain.curriculum.Curriculum;
import com.everlaw.edu.domain.curriculum.CurriculumRepository;
import com.everlaw.edu.domain.lesson.Lesson;
import com.everlaw.edu.domain.lesson.LessonRepository;
import com.everlaw.edu.domain.snapshot.ContentSnapshot;
import com.everlaw.edu.domain.snapshot.ContentSnapshotRepository;
import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class ApprovalService {

    private final CurriculumRepository curriculumRepository;
    private final LessonRepository lessonRepository;
    private final ApprovalRequestRepository approvalRequestRepository;
    private final ContentSnapshotRepository contentSnapshotRepository;
    private final ContentEventPublisher contentEventPublisher;
    private final RestClient aiEngineRestClient;
    private final QuizBankRepository quizBankRepository;
    private final ObjectMapper objectMapper;

    /**
     * 프론트엔드로부터 콘텐츠 생성 요청을 받아 FastAPI AI 엔진에 비동기로 연동을 트리거합니다.
     * WAS 리소스 절약을 위해 가상 스레드 환경에 최적화된 CompletableFuture 비동기 논블로킹 파이프라인으로 구성합니다.
     */
    public CompletableFuture<Void> triggerContentGeneration(GenerateTriggerRequest request) {
        log.info("🚀 [Generation Trigger] Initiating AI content generation for Curriculum ID: {}", request.curriculumId());
        
        // 1. 대상 커리큘럼 존재 유무 선검증 (없으면 데모용 임시 커리큘럼 자동 생성)
        Curriculum curriculum = curriculumRepository.findById(request.curriculumId())
                .orElseGet(() -> curriculumRepository.save(Curriculum.builder()
                        .title("테스트 커리큘럼")
                        .description("임시 테스트용 커리큘럼")
                        .category("안전보건")
                        .targetJobCategory("제조업")
                        .build()));

        FastApiLawChangeRequest fastApiRequest = new FastApiLawChangeRequest(request.lawId(), request.lawContent());

        // 2. 비동기 HTTP 호출 파이프라인 기동
        return CompletableFuture.runAsync(() -> {
            try {
                log.info("📡 [AI Engine Call] Sending request to FastAPI API /api/v1/generate-content...");
                
                FastApiGenerateResponse response = aiEngineRestClient.post()
                        .uri("/api/v1/generate-content")
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(fastApiRequest)
                        .retrieve()
                        .body(FastApiGenerateResponse.class);

                if (response == null || !"Success".equalsIgnoreCase(response.status())) {
                    String statusMsg = response != null ? response.status() : "NULL RESPONSE";
                    throw new RuntimeException("AI Engine returned failure status: " + statusMsg);
                }

                log.info("✅ [AI Engine Response] Successfully received generation result from AI Engine.");
                saveProposedContent(curriculum, response);

            } catch (Exception e) {
                log.error("❌ [AI Ingestion Failed] Failed to process RAG generation workflow for Curriculum ID: {}", 
                        request.curriculumId(), e);
                // 비즈니스 무중단 및 장애 전파 차단을 위해 예외를 던지지 않고 복구 흐름 처리
                saveFallbackContent(curriculum, request, e);
            }
        });
    }

    /**
     * AI 엔진의 정상 응답 데이터를 트랜잭션 범위 내에서 안전하게 PENDING 상태의 승인 대기열로 적재합니다.
     */
    @Transactional
    public void saveProposedContent(Curriculum curriculum, FastApiGenerateResponse response) {
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
                .lawReference(analysis.lawReference())
                .aiGeneratedMarkdown(analysis.contentMarkdown())
                .quizPayload(quizPayload)
                .validationDetails(validation.validationDetails())
                .hallucinationScore(validation.hallucinationScore())
                .status(ApprovalStatus.PENDING)
                .build();

        approvalRequestRepository.save(approvalRequest);
        log.info("📥 [Approval Queue] Successfully loaded AI generated content into approval request queue (ID: {})", 
                approvalRequest.getId());
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
                .aiGeneratedMarkdown(fallbackMarkdown)
                .validationDetails("AI 엔진 통신 오류 발생 폴백 모드 적재: " + ex.getMessage())
                .hallucinationScore(0.99) // 위험도 적색 경보 부과
                .status(ApprovalStatus.PENDING)
                .build();

        approvalRequestRepository.save(approvalRequest);
        log.warn("⚠️ [Approval Queue - Fallback] Loaded fallback compliance content into queue due to infrastructure exception.");
    }

    /**
     * 관리자가 승인(Approved) 또는 반려(Rejected)를 결정하는 핵심 트랜잭션입니다.
     * 모든 영속 업데이트, 역사적 스냅샷 아카이빙, Redis 이벤트 브로커 발행이 원자적으로 실행됩니다.
     */
    @Transactional
    public void processApprovalAction(Long requestId, boolean approved, String adminEmail) {
        log.info("👨‍✈️ [Admin Action] Processing approval action for Request ID: {}, Approved: {}, Admin: {}", 
                requestId, approved, adminEmail);

        ApprovalRequest request = approvalRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("ApprovalRequest not found with ID: " + requestId));

        if (approved) {
            // 1. 상태를 APPROVED로 승격
            // 2. Lesson 생성 또는 갱신 진행
            Lesson lesson = request.getLesson();
            if (lesson == null) {
                // 신규 교안 생성 시나리오
                lesson = Lesson.builder()
                        .curriculum(request.getCurriculum())
                        .title(request.getTitle())
                        .contentMarkdown(request.getAiGeneratedMarkdown())
                        .associatedLawReference(request.getLawReference())
                        .build();
                lessonRepository.save(lesson);
            } else {
                // 기존 교안 개정 갱신 시나리오
                lesson.updateContent(request.getTitle(), request.getAiGeneratedMarkdown(), request.getLawReference());
            }

            request.approve(lesson);

            // 퀴즈 데이터가 있으면 파싱해서 QuizBank에 영속화
            if (request.getQuizPayload() != null && !request.getQuizPayload().isEmpty()) {
                try {
                    Map<String, Object> quizData = objectMapper.readValue(request.getQuizPayload(), Map.class);
                    QuizBank quiz = QuizBank.builder()
                            .lesson(lesson)
                            .lawReference(request.getLawReference())
                            .question((String) quizData.get("question"))
                            .options((List<String>) quizData.get("options"))
                            .answerIndex((Integer) quizData.get("answerIndex"))
                            .hint((String) quizData.get("hint"))
                            .explanation((String) quizData.get("explanation"))
                            .build();
                    quizBankRepository.save(quiz);
                    log.info("📝 [QuizBank] Saved structured quiz for Lesson ID: {}", lesson.getId());
                } catch (Exception e) {
                    log.error("Failed to deserialize and save quiz data", e);
                }
            }

            // 3. 역사적 법적 책임 증빙을 위한 불변 비정규화 스냅샷 영구 저장
            ContentSnapshot snapshot = ContentSnapshot.builder()
                    .lesson(lesson)
                    .curriculumTitle(request.getCurriculum().getTitle())
                    .lessonTitle(lesson.getTitle())
                    .contentMarkdown(lesson.getContentMarkdown())
                    .approvedBy(adminEmail)
                    .build();
            contentSnapshotRepository.save(snapshot);
            log.info("🗄️ [Compliance Snapshot] Archiving historical snapshot for Lesson ID: {} completed.", lesson.getId());

            // 4. Redis Pub/Sub을 통한 임직원 실시간 알림 이벤트 발행
            contentEventPublisher.publishContentRelease(
                    lesson.getId(), 
                    request.getCurriculum().getTargetJobCategory(), 
                    lesson.getTitle()
            );

        } else {
            // 반려(Rejected) 시나리오
            request.reject();
            log.info("❌ [Request Rejected] Approval Request ID: {} was rejected by admin.", requestId);
        }
    }

    /**
     * 관리자 대기열 전체 목록 조회
     */
    @Transactional(readOnly = true)
    public List<ApprovalRequest> getAllRequests() {
        return approvalRequestRepository.findAll();
    }

    /**
     * 상태별 대기열 조회
     */
    @Transactional(readOnly = true)
    public List<ApprovalRequest> getRequestsByStatus(ApprovalStatus status) {
        return approvalRequestRepository.findByStatus(status);
    }
}
