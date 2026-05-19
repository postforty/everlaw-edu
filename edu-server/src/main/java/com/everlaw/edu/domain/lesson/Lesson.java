package com.everlaw.edu.domain.lesson;

import com.everlaw.edu.domain.curriculum.Curriculum;
import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "lessons", indexes = {
        @Index(name = "idx_lessons_curriculum", columnList = "curriculum_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Lesson extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "curriculum_id", nullable = false)
    private Curriculum curriculum;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "content_markdown", nullable = false, columnDefinition = "TEXT")
    private String contentMarkdown;

    @Column(name = "associated_law_reference", nullable = false, length = 150)
    private String associatedLawReference;

    @Builder
    public Lesson(Curriculum curriculum, String title, String contentMarkdown, String associatedLawReference) {
        this.curriculum = curriculum;
        this.title = title;
        this.contentMarkdown = contentMarkdown;
        this.associatedLawReference = associatedLawReference;
    }

    public void updateContent(String title, String contentMarkdown, String associatedLawReference) {
        this.title = title;
        this.contentMarkdown = contentMarkdown;
        this.associatedLawReference = associatedLawReference;
    }
}
