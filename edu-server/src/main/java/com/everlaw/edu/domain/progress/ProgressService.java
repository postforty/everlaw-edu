package com.everlaw.edu.domain.progress;

import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.domain.member.MemberRepository;
import com.everlaw.edu.domain.progress.dto.IncorrectNoteResponse;
import com.everlaw.edu.domain.progress.dto.ProgressQuizSubmitRequest;
import com.everlaw.edu.domain.progress.dto.ProgressQuizSubmitResponse;
import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProgressService {

    private final MemberIncorrectNoteRepository incorrectNoteRepository;
    private final MemberWeaknessIndexRepository weaknessIndexRepository;
    private final QuizBankRepository quizBankRepository;
    private final MemberRepository memberRepository;

    @Transactional
    public ProgressQuizSubmitResponse submitQuizResult(Long memberId, ProgressQuizSubmitRequest request) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("Member not found"));

        QuizBank quiz = quizBankRepository.findById(request.quizId())
                .orElseThrow(() -> new IllegalArgumentException("Quiz not found"));

        boolean isCorrect = request.selectedIndex().equals(quiz.getAnswerIndex());
        
        MemberWeaknessIndex weaknessIndex = weaknessIndexRepository.findByMemberIdAndLawReference(memberId, quiz.getLawReference())
                .orElseGet(() -> MemberWeaknessIndex.builder()
                        .member(member)
                        .lawReference(quiz.getLawReference())
                        .build());

        boolean isGraduated = false;

        if (isCorrect) {
            weaknessIndex.incrementCorrect();
            
            // 3 consecutive corrects -> Graduate
            if (weaknessIndex.getConsecutiveCorrects() >= 3) {
                incorrectNoteRepository.archiveByMemberIdAndLawReference(memberId, quiz.getLawReference());
                weaknessIndex.resetForGraduation();
                isGraduated = true;
                log.info("Member {} graduated from law reference: {}", memberId, quiz.getLawReference());
            }
        } else {
            weaknessIndex.incrementIncorrect();
            
            // Save or Update incorrect note
            incorrectNoteRepository.findByMemberIdAndQuizBankIdAndIsArchivedFalseAndIsDeletedFalse(memberId, quiz.getId())
                    .ifPresentOrElse(
                            note -> note.updateSelectedIndex(request.selectedIndex()),
                            () -> {
                                MemberIncorrectNote note = MemberIncorrectNote.builder()
                                        .member(member)
                                        .quizBank(quiz)
                                        .lawReference(quiz.getLawReference())
                                        .selectedIndex(request.selectedIndex())
                                        .build();
                                incorrectNoteRepository.save(note);
                            }
                    );
        }

        weaknessIndexRepository.save(weaknessIndex);

        return new ProgressQuizSubmitResponse(
                isCorrect,
                quiz.getAnswerIndex(),
                quiz.getExplanation(),
                isGraduated,
                weaknessIndex.getWeaknessScore()
        );
    }

    @Transactional
    public ProgressQuizSubmitResponse submitAdaptiveQuizResult(Long memberId, String lawReference, boolean isCorrect) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("Member not found"));

        MemberWeaknessIndex weaknessIndex = weaknessIndexRepository.findByMemberIdAndLawReference(memberId, lawReference)
                .orElseGet(() -> MemberWeaknessIndex.builder()
                        .member(member)
                        .lawReference(lawReference)
                        .build());

        boolean isGraduated = false;

        if (isCorrect) {
            weaknessIndex.incrementCorrect();
            if (weaknessIndex.getConsecutiveCorrects() >= 3) {
                incorrectNoteRepository.archiveByMemberIdAndLawReference(memberId, lawReference);
                weaknessIndex.resetForGraduation();
                isGraduated = true;
                log.info("Member {} graduated from law reference: {}", memberId, lawReference);
            }
        } else {
            weaknessIndex.incrementIncorrect();
            // Note: Adaptive quizzes are on-the-fly and not saved to QuizBank yet, 
            // so we don't create a new MemberIncorrectNote here, just update the weakness score.
        }

        weaknessIndexRepository.save(weaknessIndex);

        return new ProgressQuizSubmitResponse(
                isCorrect,
                -1, // No answer index since it's already graded
                "Adaptive quiz feedback", // No explanation needed here
                isGraduated,
                weaknessIndex.getWeaknessScore()
        );
    }

    @Transactional(readOnly = true)
    public List<IncorrectNoteResponse> getActiveIncorrectNotes(Long memberId) {
        return incorrectNoteRepository.findByMemberIdAndIsArchivedFalseAndIsDeletedFalse(memberId).stream()
                .map(IncorrectNoteResponse::from)
                .collect(Collectors.toList());
    }

    @Transactional
    public void deleteIncorrectNote(Long memberId, Long noteId) {
        incorrectNoteRepository.findById(noteId).ifPresent(note -> {
            if (note.getMember().getId().equals(memberId)) {
                note.delete();
            }
        });
    }
}
