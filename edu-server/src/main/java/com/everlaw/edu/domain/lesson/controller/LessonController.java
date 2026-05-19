package com.everlaw.edu.domain.lesson.controller;

import com.everlaw.edu.domain.lesson.Lesson;
import com.everlaw.edu.domain.lesson.dto.QuizFeedbackResponse;
import com.everlaw.edu.domain.lesson.dto.QuizSubmitRequest;
import com.everlaw.edu.domain.lesson.service.LessonService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;

    /**
     * [강좌 리스트 수강 API] 로그인한 임직원의 직무 카테고리와 대상 직무군이 일치하는 맞춤형 최신 배포 교안 목록을 서빙합니다.
     */
    @GetMapping
    public ResponseEntity<List<Lesson>> getLessons(@AuthenticationPrincipal String email) {
        log.info("📡 [GET /lessons] Fetching personalized lessons list for email: {}", email);
        List<Lesson> lessons = lessonService.getAuthorizedLessons(email);
        return ResponseEntity.ok(lessons);
    }

    /**
     * [강좌 상세 보기 API] 특정 교안의 상세 강의안 마크다운과 연계 법령 정보를 반환합니다. (불법 접근 방어용 2차 인가 검증 포함)
     */
    @GetMapping("/{id}")
    public ResponseEntity<Lesson> getLessonDetail(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal String email) {
        log.info("📡 [GET /lessons/{}] Fetching detailed lesson content for user: {}", id, email);
        Lesson lesson = lessonService.getLessonById(id, email);
        return ResponseEntity.ok(lesson);
    }

    /**
     * [모의 평가 채점 API] 임직원이 수강 완료 후, 교안 하단에 포함된 모의 평가 퀴즈를 풀고 답안을 제출할 시, 실시간 평가 피드백을 전달합니다.
     */
    @PostMapping("/quiz/submit")
    public ResponseEntity<QuizFeedbackResponse> submitQuiz(@Valid @RequestBody QuizSubmitRequest request) {
        log.info("📡 [POST /lessons/quiz/submit] Evaluating quiz submission for lesson: {}", request.lessonId());
        QuizFeedbackResponse feedback = lessonService.submitQuiz(request);
        return ResponseEntity.ok(feedback);
    }
}
