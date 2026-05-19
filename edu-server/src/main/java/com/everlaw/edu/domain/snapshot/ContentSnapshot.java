package com.everlaw.edu.domain.snapshot;

import com.everlaw.edu.domain.lesson.Lesson;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Table(name = "content_snapshots", indexes = {
        @Index(name = "idx_content_snapshots_lesson", columnList = "lesson_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class ContentSnapshot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 스냅샷이 대상으로 하는 원본 Lesson 매핑
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "lesson_id", nullable = false)
    private Lesson lesson;

    // [중요] 원본의 이름이 바뀌거나 유실되어도 과거 감사 이력을 훼손하지 않기 위한 의도적 비정규화 필드
    @Column(name = "curriculum_title", nullable = false, length = 200)
    private String curriculumTitle;

    @Column(name = "lesson_title", nullable = false, length = 200)
    private String lessonTitle;

    @Column(name = "content_markdown", nullable = false, columnDefinition = "TEXT")
    private String contentMarkdown;

    // 승인 행위를 한 관리자의 식별자 (이메일 등)
    @Column(name = "approved_by", nullable = false, length = 150)
    private String approvedBy;

    // 승인이 일어나고 스냅샷이 아카이빙된 일시
    @CreatedDate
    @Column(name = "approved_at", nullable = false, updatable = false)
    private LocalDateTime approvedAt;

    @Builder
    public ContentSnapshot(Lesson lesson, String curriculumTitle, String lessonTitle,
                           String contentMarkdown, String approvedBy) {
        this.lesson = lesson;
        this.curriculumTitle = curriculumTitle;
        this.lessonTitle = lessonTitle;
        this.contentMarkdown = contentMarkdown;
        this.approvedBy = approvedBy;
    }
}
