package com.everlaw.edu.domain.quiz;

import com.everlaw.edu.domain.lesson.Lesson;
import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.List;

@Entity
@Table(name = "quiz_bank", indexes = {
        @Index(name = "idx_quiz_bank_lesson", columnList = "lesson_id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizBank extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "lesson_id", nullable = false)
    private Lesson lesson;

    @Column(name = "law_reference", nullable = false, length = 150)
    private String lawReference;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String question;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false, columnDefinition = "jsonb")
    private List<String> options;

    @Column(name = "answer_index", nullable = false)
    private Integer answerIndex;

    @Column(columnDefinition = "TEXT")
    private String hint;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String explanation;

    @Builder
    public QuizBank(Lesson lesson, String lawReference, String question, List<String> options,
                    Integer answerIndex, String hint, String explanation) {
        this.lesson = lesson;
        this.lawReference = lawReference;
        this.question = question;
        this.options = options;
        this.answerIndex = answerIndex;
        this.hint = hint;
        this.explanation = explanation;
    }
}
