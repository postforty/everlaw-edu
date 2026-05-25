package com.everlaw.edu.domain.approval.controller;

import com.everlaw.edu.domain.approval.ApprovalRequest;
import com.everlaw.edu.domain.approval.ApprovalStatus;
import com.everlaw.edu.domain.approval.dto.ApprovalActionRequest;
import com.everlaw.edu.domain.approval.dto.GenerateTriggerRequest;
import com.everlaw.edu.domain.approval.dto.SourceLawResponse;
import com.everlaw.edu.domain.approval.service.ApprovalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/approvals")
@RequiredArgsConstructor
public class ApprovalController {

    private final ApprovalService approvalService;

    /**
     * [트리거 API] 교육 담당자가 특정 카테고리를 선택하고 개정 법령 팩트를 공급하여 신규 강의 교안 자율 생산을 개시합니다.
     * 클라이언트 대기 방지 및 타임아웃 예방을 위해 202 Accepted 코드로 즉시 접수 완료를 알립니다.
     */
    @PostMapping("/generate")
    public ResponseEntity<Map<String, String>> triggerGeneration(@Valid @RequestBody GenerateTriggerRequest request) {
        log.info("📡 [POST /approvals/generate] Received generation trigger request for Curriculum ID: {}", request.curriculumId());
        
        // 비동기 파이프라인 개시
        approvalService.triggerContentGeneration(request);

        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .body(Map.of(
                        "status", "Accepted",
                        "message", "AI 콘텐츠 생성 및 검증 요청이 성공적으로 접수되었습니다. 생산이 완료되는 즉시 관리자 검토 대기열에 적재됩니다."
                ));
    }

    /**
     * [대기열 조회 API] 관리자가 검토해야 할 승인 대기열(PENDING) 또는 전체 이력 목록을 반환합니다.
     */
    @GetMapping
    public ResponseEntity<List<ApprovalRequest>> getApprovalQueue(
            @RequestParam(value = "status", required = false) ApprovalStatus status) {
        log.info("📡 [GET /approvals] Fetching approval requests. Filter Status: {}", status);
        
        List<ApprovalRequest> requests = (status != null) 
                ? approvalService.getRequestsByStatus(status) 
                : approvalService.getAllRequests();
                
        return ResponseEntity.ok(requests);
    }

    /**
     * [출제소 API] FastAPI AI 엔진에 등록된 원본 법령(Source Laws) 목록을 조회합니다.
     */
    @GetMapping("/source-laws")
    public ResponseEntity<List<SourceLawResponse>> getSourceLaws() {
        log.info("📡 [GET /approvals/source-laws] Fetching source laws from AI Engine");
        List<SourceLawResponse> sourceLaws = approvalService.getSourceLaws();
        return ResponseEntity.ok(sourceLaws);
    }

    /**
     * [의사결정 API] 관리자가 특정 대기열 항목의 콘텐츠 품질과 팩트체크 리포트를 본 후, 최종 승인(APPROVED) 또는 반려(REJECTED) 처리합니다.
     */
    @PostMapping("/{requestId}/action")
    public ResponseEntity<Map<String, String>> processApproval(
            @PathVariable("requestId") Long requestId,
            @Valid @RequestBody ApprovalActionRequest request) {
        log.info("📡 [POST /approvals/{}/action] Decision: {}, Admin: {}", 
                requestId, request.approved(), request.adminEmail());

        approvalService.processApprovalAction(requestId, request.approved(), request.adminEmail());

        String statusMessage = request.approved() 
                ? "성공적으로 승인 완료되었습니다. 신규 교안이 배포에 등록되고 학습자에게 실시간 알림이 발송되었습니다." 
                : "콘텐츠 검토가 반려되었습니다.";

        return ResponseEntity.ok(Map.of(
                "status", "Success",
                "message", statusMessage
        ));
    }
}
