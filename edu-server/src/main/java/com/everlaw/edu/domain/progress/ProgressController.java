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

    // For demo purposes, we are hardcoding memberId = 1L.
    // In a real application, this should come from JWT / Spring Security Context.
    private final Long MOCK_MEMBER_ID = 1L;

    @PostMapping("/submit-quiz")
    public ResponseEntity<ProgressQuizSubmitResponse> submitQuizResult(
            @Valid @RequestBody ProgressQuizSubmitRequest request) {
        ProgressQuizSubmitResponse response = progressService.submitQuizResult(MOCK_MEMBER_ID, request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/submit-adaptive-quiz")
    public ResponseEntity<ProgressQuizSubmitResponse> submitAdaptiveQuizResult(
            @Valid @RequestBody AdaptiveQuizSubmitRequest request) {
        ProgressQuizSubmitResponse response = progressService.submitAdaptiveQuizResult(
                MOCK_MEMBER_ID, request.lawReference(), request.isCorrect());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/incorrect-notes")
    public ResponseEntity<List<IncorrectNoteResponse>> getIncorrectNotes() {
        List<IncorrectNoteResponse> notes = progressService.getActiveIncorrectNotes(MOCK_MEMBER_ID);
        return ResponseEntity.ok(notes);
    }
}
