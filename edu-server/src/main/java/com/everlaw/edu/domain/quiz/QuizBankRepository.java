package com.everlaw.edu.domain.quiz;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface QuizBankRepository extends JpaRepository<QuizBank, Long> {
    List<QuizBank> findByLessonId(Long lessonId);
}
