package com.everlaw.edu.domain.curriculum;

import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "curriculums")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Curriculum extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false, length = 50)
    private String category;

    @Column(name = "target_job_category", nullable = false, length = 50)
    private String targetJobCategory;

    @Builder
    public Curriculum(String title, String description, String category, String targetJobCategory) {
        this.title = title;
        this.description = description;
        this.category = category;
        this.targetJobCategory = targetJobCategory;
    }
}
