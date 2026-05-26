package com.everlaw.edu.domain.member.controller;

import com.everlaw.edu.domain.member.dto.AuthResponse;
import com.everlaw.edu.domain.member.dto.GoogleLoginRequest;
import com.everlaw.edu.domain.member.dto.LoginRequest;
import com.everlaw.edu.domain.member.dto.SignUpRequest;
import com.everlaw.edu.domain.member.service.MemberService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final MemberService memberService;

    /**
     * [회원가입 API] 임직원 및 교육 관리자가 신규 등록할 때 호출합니다.
     */
    @PostMapping("/signup")
    public ResponseEntity<AuthResponse> signUp(@Valid @RequestBody SignUpRequest request) {
        log.info("📡 [POST /auth/signup] Registration request received: {}", request.email());
        AuthResponse response = memberService.signUp(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * [로그인 API] 사용자가 이메일/비밀번호로 로그인하여 JWT 토큰을 취득할 때 호출합니다.
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("📡 [POST /auth/login] Login authentication requested: {}", request.email());
        AuthResponse response = memberService.login(request);
        return ResponseEntity.ok(response);
    }

    /**
     * [구글 소셜 로그인 API] 구글 ID 토큰을 검증하고 자체 JWT를 취득합니다.
     */
    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleLogin(@Valid @RequestBody GoogleLoginRequest request) {
        log.info("📡 [POST /auth/google] Google login authentication requested");
        AuthResponse response = memberService.googleLogin(request);
        return ResponseEntity.ok(response);
    }
}
