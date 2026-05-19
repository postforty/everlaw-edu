package com.everlaw.edu.domain.snapshot;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContentSnapshotRepository extends JpaRepository<ContentSnapshot, Long> {
    List<ContentSnapshot> findByLessonId(Long lessonId);
}
