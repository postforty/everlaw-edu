package com.everlaw.edu.domain.quiz.controller;

import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import com.everlaw.edu.domain.quiz.dto.AdaptiveQuizRequest;
import com.everlaw.edu.domain.quiz.service.AdaptiveQuizService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import com.everlaw.edu.domain.member.MemberRepository;
import com.everlaw.edu.domain.progress.MemberWeaknessIndexRepository;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Set;

@Slf4j
@RestController
@RequestMapping("/api/v1/quizzes")
@RequiredArgsConstructor
public class QuizController {

    private final QuizBankRepository quizBankRepository;
    private final AdaptiveQuizService adaptiveQuizService;
    private final MemberRepository memberRepository;
    private final MemberWeaknessIndexRepository weaknessIndexRepository;

    @GetMapping
    public ResponseEntity<List<QuizResponseDto>> getQuizzes(@AuthenticationPrincipal String email) {
        log.info("📡 [GET /quizzes] Fetching quiz feed for: {}", email);
        
        List<QuizBank> quizzes = quizBankRepository.findAll();
        
        Set<String> attemptedLawRefs = new HashSet<>();
        if (email != null && !email.equals("anonymousUser")) {
            memberRepository.findByEmail(email).ifPresent(member -> {
                weaknessIndexRepository.findByMemberId(member.getId()).forEach(wi -> {
                    attemptedLawRefs.add(wi.getLawReference());
                });
            });
        }
        
        List<QuizResponseDto> response = quizzes.stream()
                .sorted(Comparator.comparing(q -> attemptedLawRefs.contains(q.getLawReference())))
                .map(quiz -> {
            String correctAnswer = quiz.getOptions().size() > quiz.getAnswerIndex() 
                    ? quiz.getOptions().get(quiz.getAnswerIndex()) 
                    : "";
            
            return new QuizResponseDto(
                    quiz.getId().toString(),
                    quiz.getQuestion(),
                    quiz.getOptions(),
                    correctAnswer,
                    quiz.getExplanation(),
                    quiz.getLawReference()
            );
        }).collect(Collectors.toList());
        
        return ResponseEntity.ok(response);
    }

    @PostMapping("/adaptive")
    public ResponseEntity<Map<String, Object>> generateAdaptiveQuiz(
            @Valid @RequestBody AdaptiveQuizRequest request) {
        Map<String, Object> response = adaptiveQuizService.generateAdaptiveQuiz(request);
        return ResponseEntity.ok(response);
    }

    public record QuizResponseDto(
            String id,
            String question,
            List<String> options,
            String correctAnswer,
            String explanation,
            String lawReference
    ) {}
}
