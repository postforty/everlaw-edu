package com.everlaw.edu.domain.approval.service;

import com.everlaw.edu.domain.approval.ApprovalRequest;
import com.everlaw.edu.domain.approval.ApprovalRequestRepository;
import com.everlaw.edu.domain.approval.ApprovalStatus;
import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse;
import com.everlaw.edu.domain.approval.dto.FastApiLawChangeRequest;
import com.everlaw.edu.domain.approval.dto.GenerateTriggerRequest;
import com.everlaw.edu.domain.approval.dto.SourceLawResponse;
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
import org.springframework.beans.factory.annotation.Qualifier;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
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
    private final ApprovalTransactionHelper approvalTransactionHelper;
    
    @Qualifier("aiTaskExecutor")
    private final Executor aiTaskExecutor;

    /**
     * 프론트엔드로부터 콘텐츠 생성 요청을 받아 FastAPI AI 엔진에 비동기로 연동을 트리거합니다.
     * WAS 리소스 절약을 위해 가상 스레드 환경에 최적화된 CompletableFuture 비동기 논블로킹 파이프라인으로 구성합니다.
     */
    public CompletableFuture<Void> triggerContentGeneration(GenerateTriggerRequest request) {
        log.info("🚀 [Generation Trigger] Initiating AI content generation for Law ID: {}", request.lawId());
        
        // 1. 대상 커리큘럼 존재 유무 선검증 (1 조항 = 1 커리큘럼 매핑: lawId를 커리큘럼 제목으로 사용하여 조회 또는 자동 생성)
        String curriculumTitle = request.lawId();
        Curriculum curriculum = curriculumRepository.findByTitle(curriculumTitle)
                .orElseGet(() -> curriculumRepository.save(Curriculum.builder()
                        .title(curriculumTitle)
                        .description(curriculumTitle + " 전용 커리큘럼")
                        .category("안전보건")
                        .targetJobCategory("전직군")
                        .build()));

        // 2. 비동기 HTTP 호출 파이프라인 기동
        return CompletableFuture.runAsync(() -> {
            try {
                // 기존 대기열의 PENDING 항목 선삭제 (덮어쓰기 로직 대신 클렌징 후 5개 신규 삽입)
                approvalTransactionHelper.deletePendingRequests(request.lawId());
                
                java.util.List<String> previousQuestions = new java.util.ArrayList<>();
                java.util.List<FastApiGenerateResponse> successfulResponses = new java.util.ArrayList<>();
                int successCount = 0;

                for (int i = 0; i < 2; i++) {
                    FastApiLawChangeRequest fastApiRequest = new FastApiLawChangeRequest(request.lawId(), request.lawContent(), new java.util.ArrayList<>(previousQuestions));
                    try {
                        log.info("📡 [AI Engine Call] Sending request {}/2 to FastAPI API /api/v1/generate-content...", i + 1);
                        
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

                        // 나중에 한 번에 저장하기 위해 리스트에 수집 (프론트엔드 폴링 조기 종료 방지)
                        successfulResponses.add(response);
                        successCount++;
                        
                        // 다음 퀴즈 출제 시 중복 방지를 위해 질문 컨텍스트 누적
                        if (response.analysisResult() != null && response.analysisResult().quizQuestion() != null) {
                            previousQuestions.add(response.analysisResult().quizQuestion());
                        }

                        log.info("✅ [AI Engine Response] Successfully received generation result {}/2 from AI Engine.", i + 1);
                    } catch (Exception loopEx) {
                        log.error("❌ [AI Ingestion Failed] Failed to process RAG generation on iteration {}/2 for Curriculum ID: {}", 
                                i + 1, curriculum.getId(), loopEx);
                    }
                    
                    // LLM API Rate Limit(15 RPM) 방어를 위한 4초 강제 쓰로틀링
                    if (i < 4) {
                        try { Thread.sleep(4000); } catch (InterruptedException ignore) {}
                    }
                }
                
                // 프론트엔드의 폴링 로직이 1건만 생성되어도 완료된 것으로 오인하는 것을 방지하기 위해, 루프 종료 후 일괄 저장
                for (FastApiGenerateResponse response : successfulResponses) {
                    approvalTransactionHelper.saveProposedContent(curriculum, request, response);
                }
                
                if (successCount == 0) {
                    throw new RuntimeException("모든 2개의 문제 생성이 실패했습니다.");
                }
            } catch (Exception e) {
                log.error("❌ [AI Generation Pipeline Failed] Curriculum ID: {}", curriculum.getId(), e);
                // 비즈니스 무중단 및 장애 전파 차단을 위해 예외를 던지지 않고 복구 흐름 처리
                approvalTransactionHelper.saveFallbackContent(curriculum, request, e);
            }
        }, aiTaskExecutor);
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
            Lesson lesson = lessonRepository.findByAssociatedLawReference(request.getLawReference()).orElse(null);
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
                // 기존 교안 개정 갱신 시나리오 (Upsert)
                lesson.updateContent(request.getTitle(), request.getAiGeneratedMarkdown(), request.getLawReference());
            }

            request.approve(lesson);

            // 퀴즈 데이터가 있으면 파싱해서 QuizBank에 영속화
            if (request.getQuizPayload() != null && !request.getQuizPayload().isEmpty()) {
                try {
                    Map<String, Object> quizData = objectMapper.readValue(request.getQuizPayload(), Map.class);
                    
                    QuizBank existingQuiz = quizBankRepository.findByLawReference(request.getLawReference()).orElse(null);
                    if (existingQuiz != null) {
                        existingQuiz.updateQuiz(
                            (String) quizData.get("question"),
                            (List<String>) quizData.get("options"),
                            (Integer) quizData.get("answerIndex"),
                            (String) quizData.get("hint"),
                            (String) quizData.get("explanation")
                        );
                        log.info("📝 [QuizBank] Upserted (Overwritten) structured quiz for LawReference: {}", request.getLawReference());
                    } else {
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
                        log.info("📝 [QuizBank] Saved new structured quiz for Lesson ID: {}", lesson.getId());
                    }
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

    /**
     * FastAPI AI 엔진에 적재된 원본 법령 데이터를 프록시 조회합니다.
     */
    public List<SourceLawResponse> getSourceLaws() {
        try {
            log.info("📡 [AI Engine Call] Fetching source laws from FastAPI /api/v1/source-laws...");
            
            java.util.Set<String> generatedLaws = new java.util.HashSet<>();
            generatedLaws.addAll(quizBankRepository.findAllLawReferences());
            generatedLaws.addAll(approvalRequestRepository.findAllLawReferences());
            
            Map<String, Object> response = aiEngineRestClient.get()
                    .uri("/api/v1/source-laws")
                    .retrieve()
                    .body(Map.class);

            if (response != null && "Success".equalsIgnoreCase((String) response.get("status"))) {
                List<Map<String, String>> data = (List<Map<String, String>>) response.get("data");
                return data.stream()
                        .map(item -> new SourceLawResponse(
                                item.get("law_id"),
                                item.get("law_name"),
                                item.get("article"),
                                item.get("content"),
                                generatedLaws.contains(item.get("law_id"))
                        ))
                        .toList();
            }
            return List.of();
        } catch (Exception e) {
            log.error("❌ Failed to fetch source laws from AI Engine", e);
            return List.of();
        }
    }
}
