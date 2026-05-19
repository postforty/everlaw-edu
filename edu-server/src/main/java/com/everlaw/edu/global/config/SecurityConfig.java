package com.everlaw.edu.global.config;

import com.everlaw.edu.global.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // REST API 환경이므로 CSRF 및 CORS 비활성화 (CORS 필요 시 추가 구성 가능)
                .csrf(AbstractHttpConfigurer::disable)
                .cors(AbstractHttpConfigurer::disable)
                
                // Stateless 세션 정책 수립
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                
                // HTTP 요청 권한 규칙 설정
                .authorizeHttpRequests(auth -> auth
                        // 회원가입, 로그인 등 인증 통과는 전체 공개
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        // 헬스체크 및 루트 공개
                        .requestMatchers("/").permitAll()
                        .requestMatchers("/actuator/**").permitAll()
                        // 관리자 전용 교안 자율 생산 & 승인 대기열 통제
                        .requestMatchers("/api/v1/approvals/**").hasRole("ADMIN")
                        // 그 외 모든 요청은 토큰 기반 인증 필수
                        .anyRequest().authenticated()
                )
                
                // JWT 필터 추가 선적
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
