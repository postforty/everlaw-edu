package com.everlaw.edu.domain.quiz.controller;

import com.everlaw.edu.domain.quiz.QuizBank;
import com.everlaw.edu.domain.quiz.QuizBankRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/v1/quizzes")
@RequiredArgsConstructor
public class QuizController {

    private final QuizBankRepository quizBankRepository;

    @GetMapping
    public ResponseEntity<List<QuizResponseDto>> getQuizzes() {
        log.info("📡 [GET /quizzes] Fetching quiz feed");
        
        List<QuizBank> quizzes = quizBankRepository.findAll();
        
        List<QuizResponseDto> response = quizzes.stream().map(quiz -> {
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

    public record QuizResponseDto(
            String id,
            String question,
            List<String> options,
            String correctAnswer,
            String explanation,
            String lawReference
    ) {}
}
