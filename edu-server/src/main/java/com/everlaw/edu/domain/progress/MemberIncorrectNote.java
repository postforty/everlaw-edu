package com.everlaw.edu.domain.progress;

import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "member_incorrect_note", indexes = {
        @Index(name = "idx_incorrect_member", columnList = "member_id"),
        @Index(name = "idx_incorrect_law", columnList = "law_reference")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberIncorrectNote extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private QuizBank quizBank;

    @Column(name = "law_reference", nullable = false, length = 150)
    private String lawReference;

    @Column(name = "selected_index", nullable = false)
    private Integer selectedIndex;

    @Column(name = "is_archived", nullable = false)
    private Boolean isArchived = false;

    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;

    @Builder
    public MemberIncorrectNote(Member member, QuizBank quizBank, String lawReference, Integer selectedIndex) {
        this.member = member;
        this.quizBank = quizBank;
        this.lawReference = lawReference;
        this.selectedIndex = selectedIndex;
        this.isArchived = false;
        this.isDeleted = false;
    }

    public void archive() {
        this.isArchived = true;
    }

    public void delete() {
        this.isDeleted = true;
    }

    public void updateSelectedIndex(Integer selectedIndex) {
        this.selectedIndex = selectedIndex;
    }
}
