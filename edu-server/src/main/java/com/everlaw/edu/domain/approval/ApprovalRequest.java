package com.everlaw.edu.domain.approval;

import com.everlaw.edu.domain.curriculum.Curriculum;
import com.everlaw.edu.domain.lesson.Lesson;
import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "approval_requests", indexes = {
        @Index(name = "idx_approval_requests_status", columnList = "status"),
        @Index(name = "idx_approval_requests_lesson", columnList = "lesson_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ApprovalRequest extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 신규 교안 생성의 경우 최종 승인 전까지 Lesson이 없으므로 Nullable 허용
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "lesson_id", nullable = true)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private Lesson lesson;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "curriculum_id", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private Curriculum curriculum;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "law_reference", nullable = false, length = 150)
    private String lawReference;

    @Column(name = "law_reference_body", columnDefinition = "TEXT")
    private String lawReferenceBody;

    @Column(name = "ai_generated_markdown", nullable = false, columnDefinition = "TEXT")
    private String aiGeneratedMarkdown;

    @Column(name = "quiz_payload", columnDefinition = "TEXT")
    private String quizPayload;

    @Column(name = "validation_details", columnDefinition = "TEXT")
    private String validationDetails;

    @Column(name = "hallucination_score", nullable = false)
    private Double hallucinationScore;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ApprovalStatus status;

    // 동시성 제어 및 중복 승인 레이스 컨디션 방지를 위한 낙관적 락 버전 필드
    @Version
    private Long version;

    @Builder
    public ApprovalRequest(Lesson lesson, Curriculum curriculum, String title, String lawReference, String lawReferenceBody,
                           String aiGeneratedMarkdown, String quizPayload, String validationDetails, Double hallucinationScore,
                           ApprovalStatus status) {
        this.lesson = lesson;
        this.curriculum = curriculum;
        this.title = title;
        this.lawReference = lawReference;
        this.lawReferenceBody = lawReferenceBody;
        this.aiGeneratedMarkdown = aiGeneratedMarkdown;
        this.quizPayload = quizPayload;
        this.validationDetails = validationDetails;
        this.hallucinationScore = hallucinationScore;
        this.status = status != null ? status : ApprovalStatus.PENDING;
    }

    public void approve(Lesson approvedLesson) {
        if (this.status != ApprovalStatus.PENDING) {
            throw new IllegalStateException("Only PENDING requests can be approved.");
        }
        this.status = ApprovalStatus.APPROVED;
        this.lesson = approvedLesson;
    }

    public void reject() {
        if (this.status != ApprovalStatus.PENDING) {
            throw new IllegalStateException("Only PENDING requests can be rejected.");
        }
        this.status = ApprovalStatus.REJECTED;
    }

    public void updateRequest(String title, String lawReferenceBody, String aiGeneratedMarkdown, 
                              String quizPayload, String validationDetails, Double hallucinationScore) {
        this.title = title;
        this.lawReferenceBody = lawReferenceBody;
        this.aiGeneratedMarkdown = aiGeneratedMarkdown;
        this.quizPayload = quizPayload;
        this.validationDetails = validationDetails;
        this.hallucinationScore = hallucinationScore;
        this.status = ApprovalStatus.PENDING;
    }
}
