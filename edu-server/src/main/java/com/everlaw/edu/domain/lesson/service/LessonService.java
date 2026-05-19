package com.everlaw.edu.domain.lesson.service;

import com.everlaw.edu.domain.lesson.Lesson;
import com.everlaw.edu.domain.lesson.LessonRepository;
import com.everlaw.edu.domain.lesson.dto.QuizFeedbackResponse;
import com.everlaw.edu.domain.lesson.dto.QuizSubmitRequest;
import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.domain.member.MemberRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class LessonService {

    private final LessonRepository lessonRepository;
    private final MemberRepository memberRepository;

    /**
     * [임직원 직무 맞춤 인가] 로그인한 수강생의 직무 카테고리(jobCategory)에 매칭된 교안 목록만 정밀 필터링하여 안전하게 서빙합니다.
     */
    @Transactional(readOnly = true)
    public List<Lesson> getAuthorizedLessons(String email) {
        log.info("📖 [Lesson Service] Fetching authorized lessons for user: {}", email);

        Member member = memberRepository.findByEmail(email)
                .orElseThrow(() -> new EntityNotFoundException("Member not found with email: " + email));

        String userJob = member.getJobCategory();
        log.info("👤 [Job Category Check] User Job: {}", userJob);

        List<Lesson> allLessons = lessonRepository.findAll();

        // 수강생의 직무군과 커리큘럼의 대상 직무군이 1대1 매핑되거나 "ALL" 공통 규정일 경우 노출
        return allLessons.stream()
                .filter(lesson -> {
                    String targetJob = lesson.getCurriculum().getTargetJobCategory();
                    return "ALL".equalsIgnoreCase(targetJob) || targetJob.equalsIgnoreCase(userJob);
                })
                .collect(Collectors.toList());
    }

    /**
     * [교안 상세 조회] 개별 교안 상세 마크다운 반환
     */
    @Transactional(readOnly = true)
    public Lesson getLessonById(Long id, String email) {
        Lesson lesson = lessonRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Lesson not found with ID: " + id));

        Member member = memberRepository.findByEmail(email)
                .orElseThrow(() -> new EntityNotFoundException("Member not found with email: " + email));

        // 상세 조회 시에도 불법 접근 차단을 위한 이중 인가 검증
        String targetJob = lesson.getCurriculum().getTargetJobCategory();
        if (!"ALL".equalsIgnoreCase(targetJob) && !targetJob.equalsIgnoreCase(member.getJobCategory())) {
            log.warn("🚨 [Unauthorized Access Prevented] User {} tried to access lesson ID: {} belonging to segment {}", 
                    email, id, targetJob);
            throw new org.springframework.security.access.AccessDeniedException("You do not have access rights to this training course.");
        }

        return lesson;
    }

    /**
     * [자가 퀴즈 채점 시뮬레이션] 제출한 답변을 대조하여 채점 피드백을 실시간으로 반환합니다.
     */
    public QuizFeedbackResponse submitQuiz(QuizSubmitRequest request) {
        log.info("📝 [Quiz Evaluator] Grading submitted quiz for Lesson ID: {}, Answer: {}", 
                request.lessonId(), request.selectedAnswer());

        // PoC 단계 객관식 표준 시뮬레이션 (①번을 통계적 디폴트 정답으로 설정)
        boolean isCorrect = "①".equals(request.selectedAnswer()) || "1".equals(request.selectedAnswer());
        
        String explanation = isCorrect 
                ? "정답입니다! 국가표존 산업안전보건법 제14조에 따라, 사업장 내 규정 준수 및 안전 책임 의무 조항을 완벽히 이해하셨습니다."
                : "오답입니다. 원본 법령 제14조 조항에 따르면, 안전 관리 책임은 사업주 및 근로자 모두에게 공통 분담되는 의무입니다. 교안을 다시 확인해보세요.";

        return new QuizFeedbackResponse(request.lessonId(), request.selectedAnswer(), isCorrect, explanation);
    }
}
