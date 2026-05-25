package com.everlaw.edu.domain.lesson;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LessonRepository extends JpaRepository<Lesson, Long> {
    List<Lesson> findByCurriculumId(Long curriculumId);

    java.util.Optional<Lesson> findByAssociatedLawReference(String associatedLawReference);
}
