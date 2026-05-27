package com.everlaw.edu.domain.progress;

import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "member_weakness_index", indexes = {
        @Index(name = "idx_weakness_member_law", columnList = "member_id, law_reference", unique = true)
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberWeaknessIndex extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(name = "law_reference", nullable = false, length = 150)
    private String lawReference;

    @Column(name = "incorrect_count", nullable = false)
    private Integer incorrectCount = 0;

    @Column(name = "consecutive_corrects", nullable = false)
    private Integer consecutiveCorrects = 0;

    @Column(name = "weakness_score", nullable = false)
    private Double weaknessScore = 0.0;

    @Builder
    public MemberWeaknessIndex(Member member, String lawReference) {
        this.member = member;
        this.lawReference = lawReference;
        this.incorrectCount = 0;
        this.consecutiveCorrects = 0;
        this.weaknessScore = 0.0;
    }

    public void incrementIncorrect() {
        this.incorrectCount++;
        this.consecutiveCorrects = 0;
        // Simple scoring: +10 per incorrect, up to 100
        this.weaknessScore = Math.min(100.0, this.weaknessScore + 10.0);
    }

    public void incrementCorrect() {
        this.consecutiveCorrects++;
        // Decrease weakness score slightly on correct answer
        this.weaknessScore = Math.max(0.0, this.weaknessScore - 5.0);
    }

    public void resetForGraduation() {
        this.consecutiveCorrects = 0;
        this.weaknessScore = 0.0;
    }

    public void decrementForDeletion() {
        this.weaknessScore = Math.max(0.0, this.weaknessScore - 5.0);
    }
}
