package com.everlaw.edu.domain.quiz;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface QuizBankRepository extends JpaRepository<QuizBank, Long> {
    List<QuizBank> findByLessonId(Long lessonId);

    @org.springframework.data.jpa.repository.Query("SELECT q.lawReference FROM QuizBank q")
    java.util.Set<String> findAllLawReferences();

    java.util.Optional<QuizBank> findByLawReference(String lawReference);
}
