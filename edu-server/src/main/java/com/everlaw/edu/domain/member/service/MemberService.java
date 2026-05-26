package com.everlaw.edu.domain.member.service;

import com.everlaw.edu.domain.member.Member;
import com.everlaw.edu.domain.member.MemberRepository;
import com.everlaw.edu.domain.member.dto.AuthResponse;
import com.everlaw.edu.domain.member.dto.LoginRequest;
import com.everlaw.edu.domain.member.dto.SignUpRequest;
import com.everlaw.edu.global.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;
import com.everlaw.edu.domain.member.Role;
import com.everlaw.edu.domain.member.dto.GoogleLoginRequest;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;

import java.util.Collections;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    @Value("${oauth2.google.client-id}")
    private String googleClientId;

    /**
     * 신규 임직원 및 교육 담당자 회원가입 처리
     */
    @Transactional
    public AuthResponse signUp(SignUpRequest request) {
        log.info("👤 [Member Service] Attempting to sign up new email: {}", request.email());

        if (memberRepository.findByEmail(request.email()).isPresent()) {
            throw new IllegalArgumentException("Email already exists in the system: " + request.email());
        }

        // 비밀번호 BCrypt 단방향 암호화 해싱 적용
        String encodedPassword = passwordEncoder.encode(request.password());

        Member member = Member.builder()
                .email(request.email())
                .password(encodedPassword)
                .role(request.role())
                .jobCategory(request.jobCategory())
                .build();

        memberRepository.save(member);
        log.info("✅ [Member Service] Successfully registered new user ID: {}", member.getId());

        // 가입 완료 즉시 로그인을 위해 토큰 함께 리턴
        String token = jwtTokenProvider.createToken(member.getEmail(), member.getRole().name());
        return new AuthResponse(token, member.getEmail(), member.getRole(), member.getJobCategory());
    }

    /**
     * 로그인 요청을 받아 비밀번호를 대조하고 JWT 토큰을 발행합니다.
     */
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        log.info("👤 [Member Service] Login authentication request for email: {}", request.email());

        Member member = memberRepository.findByEmail(request.email())
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password."));

        if (!passwordEncoder.matches(request.password(), member.getPassword())) {
            log.warn("❌ [Authentication Failed] Password mismatch for email: {}", request.email());
            throw new BadCredentialsException("Invalid email or password.");
        }

        log.info("✅ [Authentication Success] Generating JWT token for email: {}, Role: {}", 
                member.getEmail(), member.getRole());
                
        String token = jwtTokenProvider.createToken(member.getEmail(), member.getRole().name());
        return new AuthResponse(token, member.getEmail(), member.getRole(), member.getJobCategory());
    }

    /**
     * 구글 소셜 로그인 토큰 검증 및 JWT 발급
     */
    @Transactional
    public AuthResponse googleLogin(GoogleLoginRequest request) {
        log.info("👤 [Member Service] Google login authentication request");

        GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), new GsonFactory())
                .setAudience(Collections.singletonList(googleClientId))
                .build();

        GoogleIdToken idToken;
        try {
            idToken = verifier.verify(request.idToken());
        } catch (Exception e) {
            log.error("❌ [Authentication Failed] Google ID Token verification failed", e);
            throw new BadCredentialsException("Invalid Google ID token.");
        }

        if (idToken == null) {
            throw new BadCredentialsException("Invalid Google ID token.");
        }

        GoogleIdToken.Payload payload = idToken.getPayload();
        String email = payload.getEmail();

        Member member = memberRepository.findByEmail(email).orElseGet(() -> {
            log.info("🆕 [Member Service] New Google user, registering email: {}", email);
            String randomPassword = UUID.randomUUID().toString();
            String encodedPassword = passwordEncoder.encode(randomPassword);
            
            Role role = request.role() != null ? request.role() : Role.LEARNER;
            String jobCategory = request.jobCategory() != null ? request.jobCategory() : "Google User";

            Member newMember = Member.builder()
                    .email(email)
                    .password(encodedPassword)
                    .role(role)
                    .jobCategory(jobCategory)
                    .build();
            return memberRepository.save(newMember);
        });

        log.info("✅ [Authentication Success] Generating JWT token for Google user email: {}, Role: {}",
                member.getEmail(), member.getRole());

        String token = jwtTokenProvider.createToken(member.getEmail(), member.getRole().name());
        return new AuthResponse(token, member.getEmail(), member.getRole(), member.getJobCategory());
    }
}
