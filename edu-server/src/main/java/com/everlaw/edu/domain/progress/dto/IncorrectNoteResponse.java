package com.everlaw.edu.domain.progress.dto;

import com.everlaw.edu.domain.progress.MemberIncorrectNote;

import java.time.LocalDateTime;
import java.util.List;

public record IncorrectNoteResponse(
        Long id,
        Long quizId,
        String lawReference,
        String question,
        List<String> options,
        Integer answerIndex,
        String hint,
        String explanation,
        Integer selectedIndex,
        LocalDateTime incorrectAt
) {
    public static IncorrectNoteResponse from(MemberIncorrectNote note) {
        return new IncorrectNoteResponse(
                note.getId(),
                note.getQuizBank().getId(),
                note.getLawReference(),
                note.getQuizBank().getQuestion(),
                note.getQuizBank().getOptions(),
                note.getQuizBank().getAnswerIndex(),
                note.getQuizBank().getHint(),
                note.getQuizBank().getExplanation(),
                note.getSelectedIndex(),
                note.getCreatedAt()
        );
    }
}
