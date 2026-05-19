package com.everlaw.edu.domain.member;

import com.everlaw.edu.global.domain.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "members", indexes = {
        @Index(name = "idx_members_email", columnList = "email", unique = true)
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String email;

    @Column(nullable = false, length = 100)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Column(name = "job_category", length = 50)
    private String jobCategory;

    @Builder
    public Member(String email, String password, Role role, String jobCategory) {
        this.email = email;
        this.password = password;
        this.role = role;
        this.jobCategory = jobCategory;
    }
}
