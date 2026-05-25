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
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

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
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        // 모든 오리진 패턴 허용 및 크리덴셜(쿠키/헤더 등) 전송 보장
        configuration.setAllowedOriginPatterns(List.of("*"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // REST API 환경이므로 CSRF 비활성화 및 CORS 필터 연동
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                
                // Stateless 세션 정책 수립
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                
                // HTTP 요청 권한 규칙 설정
                .authorizeHttpRequests(auth -> auth
                        // 회원가입, 로그인 등 인증 통과는 전체 공개
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        // 헬스체크 및 루트 공개
                        .requestMatchers("/").permitAll()
                        .requestMatchers("/actuator/**").permitAll()
                        // 데모 개발 편의를 위해 최신 레슨 및 결재 요청 목록을 전체 공개 허용
                        .requestMatchers("/api/v1/lessons/**", "/api/v1/lessons").permitAll()
                        .requestMatchers("/api/v1/approvals/**", "/api/v1/approvals").permitAll()
                        // 그 외 모든 요청은 토큰 기반 인증 필수
                        .anyRequest().authenticated()
                )
                
                // JWT 필터 추가 선적
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
