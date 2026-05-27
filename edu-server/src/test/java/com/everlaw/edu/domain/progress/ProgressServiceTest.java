package com.everlaw.edu.domain.progress;

import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.domain.member.MemberRepository;
import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ProgressServiceTest {

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private MemberIncorrectNoteRepository incorrectNoteRepository;

    @Mock
    private MemberWeaknessIndexRepository weaknessIndexRepository;

    @Mock
    private QuizBankRepository quizBankRepository;

    @InjectMocks
    private ProgressService progressService;

    private Member member;
    private MemberIncorrectNote note;
    private MemberWeaknessIndex weaknessIndex;

    @BeforeEach
    void setUp() {
        member = mock(Member.class);
        lenient().when(member.getId()).thenReturn(1L);

        QuizBank quizBank = mock(QuizBank.class);

        note = spy(MemberIncorrectNote.builder()
                .member(member)
                .quizBank(quizBank)
                .lawReference("LAW-001")
                .selectedIndex(2)
                .build());
        ReflectionTestUtils.setField(note, "id", 100L);

        weaknessIndex = spy(MemberWeaknessIndex.builder()
                .member(member)
                .lawReference("LAW-001")
                .build());
        ReflectionTestUtils.setField(weaknessIndex, "id", 200L);

        // 기본 취약 지수 부여 (+10.0점, incorrectCount = 1)
        weaknessIndex.incrementIncorrect(); 
    }

    @Test
    void deleteIncorrectNote_정상삭제시_취약지수_5점차감() {
        // given
        when(memberRepository.findByEmail("test@test.com")).thenReturn(Optional.of(member));
        when(incorrectNoteRepository.findById(100L)).thenReturn(Optional.of(note));
        when(weaknessIndexRepository.findByMemberIdAndLawReference(1L, "LAW-001"))
                .thenReturn(Optional.of(weaknessIndex));

        // when
        progressService.deleteIncorrectNote("test@test.com", 100L);

        // then
        verify(note, times(1)).delete();
        verify(weaknessIndex, times(1)).decrementForDeletion();

        assertThat(note.getIsDeleted()).isTrue();
        assertThat(weaknessIndex.getWeaknessScore()).isEqualTo(5.0); // 10.0 - 5.0 = 5.0
        assertThat(weaknessIndex.getIncorrectCount()).isEqualTo(1); // 통계 목적 카운트는 유지
    }

    @Test
    void deleteIncorrectNote_아웃박스_이중요청시_차감방어() {
        // given
        note.delete(); // 이미 논리 삭제된 상태 (아웃박스 패턴에서 중복 요청)
        
        when(memberRepository.findByEmail("test@test.com")).thenReturn(Optional.of(member));
        when(incorrectNoteRepository.findById(100L)).thenReturn(Optional.of(note));

        // when
        progressService.deleteIncorrectNote("test@test.com", 100L);

        // then
        // 삭제 로직이 더 이상 실행되지 않으므로 추가 조회나 차감이 없어야 함
        verify(weaknessIndexRepository, never()).findByMemberIdAndLawReference(anyLong(), anyString());
        assertThat(weaknessIndex.getWeaknessScore()).isEqualTo(10.0); // 원래 점수 유지
    }

    @Test
    void deleteIncorrectNote_이미_졸업한_항목은_차감무시() {
        // given
        note.archive(); // 3회 연속 정답으로 이미 졸업(아카이브)된 상태
        
        when(memberRepository.findByEmail("test@test.com")).thenReturn(Optional.of(member));
        when(incorrectNoteRepository.findById(100L)).thenReturn(Optional.of(note));

        // when
        progressService.deleteIncorrectNote("test@test.com", 100L);

        // then
        verify(note, times(1)).delete(); // 오답노트 자체는 삭제 처리 (UI 반영을 위해)
        
        // 그러나 취약 지수는 더 이상 차감하지 않음
        verify(weaknessIndexRepository, never()).findByMemberIdAndLawReference(anyLong(), anyString());
    }
}
