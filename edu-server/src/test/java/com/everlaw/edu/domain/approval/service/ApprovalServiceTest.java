package com.everlaw.edu.domain.approval.service;

import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse;
import com.everlaw.edu.domain.approval.dto.FastApiLawChangeRequest;
import com.everlaw.edu.domain.approval.dto.GenerateTriggerRequest;
import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse.AnalysisResult;
import com.everlaw.edu.domain.approval.dto.FastApiGenerateResponse.ValidationResult;
import com.everlaw.edu.domain.curriculum.Curriculum;
import com.everlaw.edu.domain.curriculum.CurriculumRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ApprovalServiceTest {

    @Mock
    private CurriculumRepository curriculumRepository;

    @Mock
    private ApprovalTransactionHelper approvalTransactionHelper;

    @Mock(answer = Answers.RETURNS_DEEP_STUBS)
    private RestClient aiEngineRestClient;

    @Mock
    private Executor aiTaskExecutor;

    private ApprovalService approvalService;

    @BeforeEach
    void setUp() {
        // 비동기 Executor를 동기적으로 실행하도록 오버라이드하여 테스트 용이성 확보
        doAnswer(invocation -> {
            Runnable runnable = invocation.getArgument(0);
            runnable.run();
            return null;
        }).when(aiTaskExecutor).execute(any(Runnable.class));

        approvalService = new ApprovalService(
                curriculumRepository,
                null,
                null,
                null,
                null,
                aiEngineRestClient,
                null,
                null,
                approvalTransactionHelper,
                aiTaskExecutor
        );
    }

    @Test
    @DisplayName("일괄 출제 (5회 반복) 로직이 정상적으로 동작하고 중복 방지 컨텍스트(previousQuestions)가 누적되는지 검증")
    void testTriggerContentGeneration_success() {
        // given
        GenerateTriggerRequest request = new GenerateTriggerRequest(1L, "산업안전보건법 제38조", "작업장 안전 조치 사항...");
        Curriculum curriculum = Curriculum.builder().title("산업안전보건법 제38조").build();
        
        when(curriculumRepository.findByTitle("산업안전보건법 제38조")).thenReturn(Optional.of(curriculum));

        // Mock AI Engine Response
        FastApiGenerateResponse mockResponse = mock(FastApiGenerateResponse.class);
        when(mockResponse.status()).thenReturn("Success");
        AnalysisResult mockAnalysisResult = mock(AnalysisResult.class);
        when(mockResponse.analysisResult()).thenReturn(mockAnalysisResult);
        
        // 각 호출마다 다른 질문을 리턴한다고 가정 (중복 방지가 잘 쌓이는지 확인하기 위함)
        java.util.concurrent.atomic.AtomicInteger questionCounter = new java.util.concurrent.atomic.AtomicInteger(1);
        when(mockAnalysisResult.quizQuestion()).thenAnswer(inv -> "Question " + questionCounter.getAndIncrement());

        // RestClient Deep Stubbing Mock
        when(aiEngineRestClient.post()
                .uri("/api/v1/generate-content")
                .contentType(MediaType.APPLICATION_JSON)
                .body(any(FastApiLawChangeRequest.class))
                .retrieve()
                .body(FastApiGenerateResponse.class))
                .thenReturn(mockResponse);

        // when
        CompletableFuture<Void> future = approvalService.triggerContentGeneration(request);
        future.join(); // executor가 동기적으로 실행하므로 바로 끝남

        // then
        // 1. 기존 PENDING 삭제 로직 호출 검증
        verify(approvalTransactionHelper, times(1)).deletePendingRequests("산업안전보건법 제38조");

        // 2. AI 엔드포인트 호출 캡처 (Deep Stub 특성상 atLeast 사용)
        ArgumentCaptor<FastApiLawChangeRequest> requestCaptor = ArgumentCaptor.forClass(FastApiLawChangeRequest.class);
        verify(aiEngineRestClient.post().uri("/api/v1/generate-content").contentType(MediaType.APPLICATION_JSON), atLeast(5))
                .body(requestCaptor.capture());

        // 3. saveProposedContent 5회 호출 검증
        verify(approvalTransactionHelper, times(5)).saveProposedContent(eq(curriculum), eq(request), eq(mockResponse));

        // 4. previousQuestions 배열이 순차적으로 올바르게 누적되어 전달되었는지 검증
        // Deep stub verify 과정에서 중복 캡처될 수 있으므로, 뒤에서 5개를 추출
        List<FastApiLawChangeRequest> capturedRequests = requestCaptor.getAllValues();
        assertTrue(capturedRequests.size() >= 5);
        List<FastApiLawChangeRequest> actualRequests = capturedRequests.subList(capturedRequests.size() - 5, capturedRequests.size());
        
        // 첫 번째 호출: 빈 배열
        assertTrue(actualRequests.get(0).previousQuestions().isEmpty());
        // 두 번째 호출: 누적된 요소가 1개 존재해야 함
        assertEquals(1, actualRequests.get(1).previousQuestions().size());
        // 마지막 호출: 앞선 4번의 반복에서 누적된 4개의 질문이 포함되어야 함
        assertEquals(4, actualRequests.get(4).previousQuestions().size());
    }

    @Test
    @DisplayName("5회 생성 중 1회가 실패(부분 성공 허용)하더라도 나머지 작업이 완료되고 Fallback되지 않는지 검증")
    void testTriggerContentGeneration_partialSuccess() {
        // given
        GenerateTriggerRequest request = new GenerateTriggerRequest(2L, "테스트 법령", "내용");
        Curriculum curriculum = Curriculum.builder().title("테스트 법령").build();
        when(curriculumRepository.findByTitle("테스트 법령")).thenReturn(Optional.of(curriculum));

        FastApiGenerateResponse mockResponse = mock(FastApiGenerateResponse.class);
        when(mockResponse.status()).thenReturn("Success");
        AnalysisResult mockAnalysisResult = mock(AnalysisResult.class);
        when(mockResponse.analysisResult()).thenReturn(mockAnalysisResult);
        when(mockAnalysisResult.quizQuestion()).thenReturn("Question");

        // 3번째 호출에서 예외를 던지도록 설정
        when(aiEngineRestClient.post()
                .uri("/api/v1/generate-content")
                .contentType(MediaType.APPLICATION_JSON)
                .body(any(FastApiLawChangeRequest.class))
                .retrieve()
                .body(FastApiGenerateResponse.class))
                .thenReturn(mockResponse)      // 1st
                .thenReturn(mockResponse)      // 2nd
                .thenThrow(new RuntimeException("AI Engine Error (3rd call)")) // 3rd
                .thenReturn(mockResponse)      // 4th
                .thenReturn(mockResponse);     // 5th

        // when
        CompletableFuture<Void> future = approvalService.triggerContentGeneration(request);
        future.join();

        // then
        // saveProposedContent가 예외가 발생한 3번째를 제외하고 총 4번 호출되었는지 검증 (부분 성공 허용 검증)
        verify(approvalTransactionHelper, times(4)).saveProposedContent(eq(curriculum), eq(request), eq(mockResponse));
        
        // 부분 성공이므로 Fallback이 호출되지 않아야 함
        verify(approvalTransactionHelper, never()).saveFallbackContent(any(), any(), any());
    }
}
