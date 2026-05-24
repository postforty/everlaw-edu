# 실제 데이터 연동을 위한 구현 계획 (Real Data Integration Plan)

## 1. 개요
현재 `edu-client` 플러터 앱 내에 하드코딩된 Mock 데이터 및 딜레이 시뮬레이션을 제거하고, 백엔드 서버(`edu-server` 등)와 실제 API 통신을 연동하기 위한 단계별 구현 계획입니다.

## 2. 연동 대상 기능 및 작업 내역

### 2.1. 결재 시스템 (Approval System)
*   **현재 상태:** `approval_provider.dart`에서 `_mockApprovals` 사용 및 삭제 시 `Future.delayed` 기반 시뮬레이션. `approval_detail_screen.dart`에서 모의 법령 본문 사용.
*   **작업 계획:**
    *   **조회 연동**: `GET /api/v1/approvals` (예시) API를 호출하여 서버의 결재 대기열 목록을 조회하고 Riverpod 상태에 반영.
    *   **상태 변경 연동**: 결재 승인/반려 시 `POST /api/v1/approvals/{id}/approve` API를 호출하고, 서버 응답이 성공(200 OK)일 때만 로컬 리스트 상태를 업데이트.
    *   **상세 연동**: 하드코딩된 `_getMockLawReferenceBody` 함수를 제거하고, 리스트 조회 시 또는 상세 조회 API를 통해 서버에서 전달받은 `lawReferenceBody`를 직접 렌더링.

### 2.2. 준법 지원 AI 챗봇 (Chatbot)
*   **현재 상태:** `chatbot_provider.dart`에서 `_generateSmartResponse`를 통한 하드코딩된 키워드 매칭 응답 및 1.2초 강제 타이핑 딜레이 사용.
*   **작업 계획:**
    *   **서버 연동**: 서버의 챗봇 연동 API 엔드포인트(`POST /api/v1/chat`)와 통신.
    *   **요청**: 사용자의 메시지와 컨텍스트(현재 학습 중인 법령 참조 정보 등)를 페이로드에 담아 전송.
    *   **응답**: 강제 딜레이(`Future.delayed`)를 제거하고, 실제 비동기 통신 대기 시간 동안만 타이핑 인디케이터를 띄움. 서버로부터 응답받은 실제 AI 답변(마크다운 등)을 파싱하여 `ChatMessage` 객체로 추가.

### 2.3. 퀴즈 문제 은행 (Quiz System)
*   **현재 상태:** `quiz_bank_provider.dart` 내부에서 정해진 4개의 `QuizItem` 목록을 정적으로 반환.
*   **작업 계획:**
    *   **조회 연동**: `GET /api/v1/quizzes` API를 통해 현재 사용자 진도 및 카테고리에 맞는 퀴즈 목록을 동적으로 요청.
    *   **직렬화**: 가져온 JSON 데이터를 `QuizItem` 모델 형식에 맞춰 직렬화(fromMap). 
    *   **데이터 소스 변경**: Riverpod Provider를 FutureProvider 기반으로 변경하여 서버 패치 로직으로 교체.

### 2.4. 맞춤형 취약점 클리닉 (Adaptive Quiz Clinic)
*   **현재 상태:** `adaptive_quiz_clinic_screen.dart`에서 2초 딜레이 후 `_simulatedMarkdown` 변수에 정적 퀴즈 시나리오 할당. 정답 처리도 클라이언트에서 문자열 기반으로 판단.
*   **작업 계획:**
    *   **문제 생성 연동**: 사용자의 취약 법령 조항을 기반으로 서버에 문제 생성 요청(`POST /api/v1/quizzes/adaptive`).
    *   **렌더링**: 서버/LLM이 온더플라이로 생성한 마크다운 퀴즈 시나리오를 받아와 화면에 렌더링.
    *   **채점 연동**: 사용자가 답안을 선택하면 `POST /api/v1/quizzes/submit` API를 호출해 서버에서 정답 여부 및 피드백 해설을 생성하여 클라이언트로 반환하도록 로직을 위임.

### 2.5. 푸시 알림 (Push Notifications)
*   **현재 상태:** `push_notification_service.dart`에서 가짜 FCM 토큰 반환 및 `triggerMockNotification`을 통한 로컬 이벤트 흉내.
*   **작업 계획:**
    *   **Firebase 설정**: 실제 `google-services.json` 및 `GoogleService-Info.plist` 구성(플랫폼별 설정).
    *   **토큰 등록**: `FirebaseMessaging.instance.getToken()`을 통해 실제 기기 토큰을 발급받고, 이를 서버(`POST /api/v1/users/device-token`)에 등록.
    *   **이벤트 수신**: 실제 Firebase 백그라운드 메시징 핸들러를 구현하여, 서버에서 발송된 알림 클릭 시 특정 화면으로 네비게이션 되도록 라우팅 처리 연동.

### 2.6. 오답노트 및 학습 진도 동기화 (Incorrect Note & Mastery Sync)
*   **현재 상태:** `incorrect_note_provider.dart` 내부에서 `SharedPreferences`를 사용하여 오답노트 목록과 연속 정답 횟수에 기반한 마스터리 상태를 기기 로컬에만 저장 및 관리 중.
*   **작업 계획:**
    *   **학습 결과 전송:** 퀴즈 풀이 완료 시 로컬 저장이 아닌 `POST /api/v1/progress/quiz-result` API를 호출하여 서버에 사용자의 정답/오답 결과(법령 조항 포함) 전송.
    *   **학습 진도 동기화:** `GET /api/v1/progress/incorrect-notes` 등의 API를 통해 서버와 동기화된 오답노트 및 취약점 통계 데이터를 조회하여 Riverpod 상태에 반영.
    *   **연계:** 맞춤형 취약점 클리닉(Adaptive Quiz)이 해당 서버 기반 취약점 데이터를 참조하도록 데이터 플로우 변경.

### 2.7. 사용자 인증 (Auth) 시스템 보완
*   **현재 상태:** `auth_provider.dart`에서 `DemoRole` (learner, admin)에 따라 하드코딩된 이메일과 비밀번호로 자동 로그인/회원가입을 시도하는 데모 로직이 적용되어 있음 (`main.dart`의 WelcomeScreen에서 백그라운드 호출).
*   **작업 계획:** 
    *   **UI 연동:** 실제 사용자 로그인/회원가입 UI를 구성하고, 사용자가 입력한 자격 증명을 기반으로 `/api/v1/auth/login` 또는 `/api/v1/auth/signup` API 호출하도록 인증 흐름 교체.
    *   **자동 로그인:** 스플래시 화면에서 JWT 토큰 유효성 검사 및 토큰 갱신(Refresh) API 호출 로직 추가.

## 3. 공통 인프라 (Network Layer) 연동 계획
실제 API 통신을 위해 다음 인프라를 우선 구축해야 합니다.

1.  **네트워크 패키지 구성**: `dio` 또는 `http` 패키지 세팅. Base URL, Timeout 등의 기본 옵션 설정.
2.  **인터셉터(Interceptor) 구축**:
    *   **인증(Auth)**: 요청 헤더에 JWT 토큰 자동 주입.
    *   **로깅(Logging)**: 디버그 모드에서 요청/응답 로그 출력.
    *   **에러 핸들링**: 401(토큰 만료), 500(서버 에러) 발생 시 공통 스낵바 또는 리다이렉트 처리.
3.  **환경 변수 분리**: `flutter_dotenv` 등을 도입하여 `.env` 파일 기반으로 로컬 개발 서버(`http://localhost:8080`)와 상용 운영 서버 환경 분리.

---

## 4. TDD (Test-Driven Development) 적용 전략

목데이터를 걷어내고 실제 API를 연동하는 과정에서 발생할 수 있는 부작용(Side Effect)을 최소화하고 안정성을 확보하기 위해 **TDD(테스트 주도 개발)** 방법론을 적용합니다.

1. **Red (테스트 실패):** 실제 연동 코드를 작성하기 전, `mockito` 또는 `mocktail`을 이용하여 HTTP 클라이언트(`Dio`)의 API 응답을 모방(Mocking)하는 **단위 테스트(Unit Test)**를 먼저 작성합니다.
2. **Green (테스트 통과):** 테스트를 통과할 수 있는 최소한의 실제 연동 코드(API 호출, JSON 파싱, 상태 업데이트)를 작성하여 기존의 하드코딩된 목데이터를 대체합니다.
3. **Refactor (리팩토링):** 중복 코드를 제거하고 Riverpod 상태 관리 구조를 개선하며, 위젯 테스트(Widget Test)를 통해 UI 연동이 정상적으로 맞물려 돌아가는지 검증합니다.

---

## 5. 구현 태스크 리스트 (Implementation Task List)

오해나 누락 없이 체계적인 데이터 연동 및 TDD 기반 작업을 진행할 수 있도록 구성한 구체적인 체크리스트입니다. 각 기능 구현 전 반드시 **테스트 코드를 선행 작성**합니다.

### Phase 1: 공통 인프라 및 인증 시스템 연동
- [x] **1.1 네트워크 계층 구축 및 TDD 환경 세팅**
  - [x] `mockito`, `flutter_test` 등 테스트 패키지 설정 및 `MockDio` 헬퍼 클래스 구성
  - [x] `flutter_dotenv` 패키지 설치 및 `.env` 환경 변수 파일 구성 (로컬/상용 분리)
  - [x] `dio` 인스턴스 기본 설정 (Base URL, Timeout) 및 JWT 인증 인터셉터 부착
- [x] **1.2 사용자 인증(Auth) 연동 (TDD 적용)**
  - [x] **[Test]** 로그인/회원가입 API의 성공/실패 응답에 대한 `AuthService` 단위 테스트 작성 (Red)
  - [x] `auth_provider.dart` 내 하드코딩된 데모 계정 자동 로그인 시도 로직 제거 및 실제 API 통신 구현 (Green)
  - [x] 스플래시 화면(`WelcomeScreen`) 진입 시 JWT 토큰 유효성 검사 및 자동 로그인 로직 리팩토링 (Refactor)
  - [x] 사용자 이메일/비밀번호 입력을 위한 실제 로그인 UI 화면 연동 개발

### Phase 2: 핵심 학습 시스템 연동
- [x] **2.1 퀴즈 문제 은행 API 연동 (TDD 적용)**
  - [x] **[Test]** `GET /api/v1/quizzes` API 호출 성공 및 `QuizItem` JSON 직렬화 검증 단위 테스트 작성
  - [x] `quiz_bank_provider.dart`의 정적 목록 리턴 로직 제거 및 네트워크 패치 위임 구현
  - [x] Riverpod Provider를 비동기 패치 모델(FutureProvider 등)로 리팩토링
- [x] **2.2 준법 지원 AI 챗봇 연동 (TDD 적용)**
  - [x] **[Test]** `POST /api/v1/chat` 응답 파싱 및 `ChatMessage` 상태 추가 검증 테스트 작성
  - [x] `chatbot_provider.dart` 내 1.2초 강제 딜레이 시뮬레이션 및 하드코딩 응답 제거
  - [x] 네트워크 대기 시간 동안만 타이핑 인디케이터를 노출하는 UI 연동 및 리팩토링

### Phase 3: 학습 진도 관리 및 맞춤형 클리닉 연동
- [x] **3.1 오답노트 및 학습 진도 동기화 (TDD 적용)**
  - [x] **[Test]** 학습 결과 전송(`POST`) 및 오답노트 로딩(`GET`) 데이터 정합성 단위/통합 테스트 작성
  - [x] `incorrect_note_provider.dart` 내 `SharedPreferences` 기반 로컬 Only 저장 로직 제거
  - [x] 서버와 동기화된 오답노트 상태를 기반으로 UI를 업데이트하도록 리팩토링
- [x] **3.2 맞춤형 취약점 클리닉 (TDD 적용)**
  - [x] **[Test]** 취약점 조항 기반 퀴즈 생성(`POST /api/v1/quizzes/adaptive`) 및 마크다운 응답 파싱 테스트 작성
  - [x] `adaptive_quiz_clinic_screen.dart` 내 2초 딜레이 및 정적 마크다운(`_simulatedMarkdown`) 할당 로직 제거
  - [x] 온더플라이 생성 마크다운 렌더링 및 풀이 제출 API 채점 위임 구현

### Phase 4: 관리자 시스템 및 푸시 알림 연동
- [x] **4.1 결재 시스템 (Approval System) 연동 (TDD 적용)**
  - [x] **[Test]** 결재 대기열 목록 조회 및 승인/반려 상태 변경 로직 검증 단위 테스트 작성
  - [x] `approval_provider.dart` 내 `_mockApprovals` 정적 배열 및 딜레이 흉내 로직 완전 제거 및 API 연동
  - [x] `approval_detail_screen.dart` 내부의 모의 법령 텍스트 생성기(`_getMockLawReferenceBody`) 제거 및 API 응답 텍스트 바인딩
- [x] **4.2 푸시 알림 인프라 연동**
  - [x] Firebase 플랫폼 설정 (`google-services.json`, `GoogleService-Info.plist`) 및 가짜 이벤트 로직 제거
  - [x] 실제 푸시 토큰 획득 및 백엔드 등록(`POST /api/v1/users/device-token`) 통합 로직 작성
  - [x] FCM 백그라운드 메시징 수신 핸들러 구현 및 알림 클릭 시 딥링크 라우팅 검증 테스트
