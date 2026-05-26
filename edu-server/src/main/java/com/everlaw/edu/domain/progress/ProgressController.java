package com.everlaw.edu.domain.progress;

import com.everlaw.edu.domain.progress.dto.IncorrectNoteResponse;
import com.everlaw.edu.domain.progress.dto.ProgressQuizSubmitRequest;
import com.everlaw.edu.domain.progress.dto.ProgressQuizSubmitResponse;
import com.everlaw.edu.domain.progress.dto.AdaptiveQuizSubmitRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/progress")
@RequiredArgsConstructor
public class ProgressController {

    private final ProgressService progressService;

    @PostMapping("/submit-quiz")
    public ResponseEntity<ProgressQuizSubmitResponse> submitQuizResult(
            @org.springframework.security.core.annotation.AuthenticationPrincipal String email,
            @Valid @RequestBody ProgressQuizSubmitRequest request) {
        ProgressQuizSubmitResponse response = progressService.submitQuizResult(email, request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/submit-adaptive-quiz")
    public ResponseEntity<ProgressQuizSubmitResponse> submitAdaptiveQuizResult(
            @org.springframework.security.core.annotation.AuthenticationPrincipal String email,
            @Valid @RequestBody AdaptiveQuizSubmitRequest request) {
        ProgressQuizSubmitResponse response = progressService.submitAdaptiveQuizResult(
                email, request.lawReference(), request.isCorrect());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/incorrect-notes")
    public ResponseEntity<List<IncorrectNoteResponse>> getIncorrectNotes(
            @org.springframework.security.core.annotation.AuthenticationPrincipal String email) {
        List<IncorrectNoteResponse> notes = progressService.getActiveIncorrectNotes(email);
        return ResponseEntity.ok(notes);
    }

    @DeleteMapping("/incorrect-notes/{noteId}")
    public ResponseEntity<Void> deleteIncorrectNote(
            @org.springframework.security.core.annotation.AuthenticationPrincipal String email,
            @PathVariable Long noteId) {
        progressService.deleteIncorrectNote(email, noteId);
        return ResponseEntity.noContent().build();
    }
}
