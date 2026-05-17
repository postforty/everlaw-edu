# [구현 계획서] EverLaw Edu 솔루션 개발 계획

**작성자**: Senior Full-Stack Engineer
**목적**: PRD 및 기능 명세서를 바탕으로, 기 구축된 AI 엔진을 확장하고 Spring Boot 백엔드와 Flutter 프론트엔드를 통합하여 전체 시스템을 완성하기 위한 단계별 실행 계획을 정의합니다.

---

## 1. 개요 및 현재 시스템 상태
현재(Phase 1 초기) 로컬 Mac Mini 환경에서 컨테이너 기반 인프라(Ollama, PostgreSQL/pgvector, Redis) 구성이 완료되었으며, Python 기반 `ai-engine` 스켈레톤(FastAPI, LangGraph 기반 RAG, 법령 스캐너)이 일부 구현된 상태입니다. 

**향후 핵심 과제**:
1. AI 엔진의 실질적인 차분 분석 로직 완성
2. 관리자/학습자 도메인을 관리할 Spring Boot 비즈니스 서버 구축
3. 멀티 플랫폼(Android/iOS/Web) 지원을 위한 Flutter 앱 개발
4. 시스템 간 유기적인 연동 및 통합 테스트

---

## 2. 아키텍처 및 기술 스택 

### 2.1 인프라 및 통신
- **Local Hosting**: Mac Mini (Docker Compose 기반)
- **Database**: PostgreSQL 16 (pgvector), Redis (Cache & Queue)
- **통신 규격**: REST API 및 비동기 메시지 큐 (Redis Pub/Sub)

### 2.2 AI Engine (존재)
- **Framework**: Python 3.12+, FastAPI
- **AI/LLM**: Google Gemini 3.1 Flash-Lite, Ollama (bge-m3 Embedding)
- **Workflow**: LangChain, LangGraph

### 2.3 Back-end (신규)
- **Framework**: Spring Boot 3.x, Java 21 (또는 Kotlin)
- **ORM / DB**: Spring Data JPA, Hibernate, PostgreSQL
- **Security**: Spring Security, JWT (인증/인가)

### 2.4 Front-end (신규)
- **Framework**: Flutter 3.x (Dart)
- **State Management**: Provider 또는 Riverpod
- **UI/UX**: Markdown 렌더링 엔진 (flutter_markdown), 다크모드 지원

---

## 3. 단계별 구현 계획 (Phased Implementation Plan)

### Phase 1: AI 엔진 고도화 및 데이터 정제 (Week 1-2)
현재 구현된 스켈레톤 코드를 실제 비즈니스 로직으로 채우는 단계입니다.

*   **1.1 스캐너 고도화 (`scanner_main.py` & `law_scanner.py`)**
    *   [x] Github `legalize-kr` 레포지토리의 커밋 데이터로부터 추가/삭제된 조항(Diff) 텍스트를 정확하게 추출하는 로직 구현
    *   [x] 추출된 데이터를 Vector DB에 Embedding하여 적재하는 파이프라인 완성
*   **1.2 지능형 차분 분석 및 RAG 구현 (`rag_engine.py`)**
    *   [x] 개정된 법령(Context)이 입력되면, Vector DB에서 기존 교육 커리큘럼(Markdown)을 검색(Retrieval)
    *   [x] Gemini 모델을 활용해 어느 섹션을 어떻게 수정해야 하는지 구체적인 JSON 형태의 응답(차분 결과)을 생성하도록 프롬프트 튜닝
*   **1.3 AI 검증(Validation) 노드 추가**
    *   [x] LangGraph 워크플로우에 `validate` 노드를 추가하여, 생성된 수정안이 원본 법령을 훼손하지 않는지 환각(Hallucination) 검사 수행

### Phase 2: Spring Boot 비즈니스 서버 구축 (Week 3-4)
MSA 아키텍처의 중심 역할을 할 API 서버를 개발합니다.

*   **2.1 프로젝트 초기화 및 DB 설계**
    *   [ ] Spring Boot 프로젝트 세팅 (JPA, Web, Security, PostgreSQL 드라이버)
    *   [ ] Entity 설계: `Member`(사용자), `Curriculum`(교육 과정), `Lesson`(학습 단위), `ContentVersion`(콘텐츠 버전, JPA Auditing 적용), `ApprovalRequest`(관리자 승인 대기열)
*   **2.2 AI Engine 연동 및 웹훅(Webhook) API**
    *   [ ] AI Engine이 백엔드로 분석 완료 및 수정안을 전달할 콜백(Callback) API 엔드포인트 구현
    *   [ ] `ApprovalRequest` 생성 로직 및 관리자에게 알림을 보내는 Redis Pub/Sub 로직 구성
*   **2.3 프론트엔드 제공 API 개발**
    *   [ ] 인증(Login/Token) 및 권한 관리(Admin/Learner)
    *   [ ] 교육 과정 목록, 강의 상세(Markdown), 승인 대기열 조회/처리 API 구현

### Phase 3: Flutter 프론트엔드 구축 (Week 5-6)
하나의 코드베이스로 관리자 웹 대시보드와 학습자 모바일 앱을 구성합니다.

*   **3.1 공통 및 코어 모듈 구성**
    *   [ ] Flutter 프로젝트 구조 세팅 (Domain-Driven 폴더 구조, 라우팅 세팅)
    *   [ ] API 클라이언트 (Dio) 및 상태 관리(Riverpod) 구성
    *   [ ] Markdown 렌더링 전용 커스텀 위젯 개발 (코드 블록, 인용구, 강조 등 테마 적용)
*   **3.2 관리자 대시보드 (Web Target)**
    *   [ ] 변경된 교육 콘텐츠의 Before & After를 보여주는 Side-by-Side Diff 뷰어 구현
    *   [ ] 콘텐츠 승인/반려 워크플로우 UI 및 상태 업데이트 기능
*   **3.3 학습자용 앱 (Mobile Target)**
    *   [ ] 사용자 맞춤형 교육 커리큘럼 대시보드
    *   [ ] FCM 연동을 통한 법령 개정 및 신규 교육 업데이트 푸시 알림 수신

### Phase 4: 통합 테스트 및 배포 안정화 (Week 7-8)
전체 시스템의 유기적인 동작을 검증합니다.

*   **4.1 E2E 통합 테스트**
    *   [ ] 모의 법령 개정 이벤트 발생 -> AI 차분 분석 -> 백엔드 승인 요청 -> 관리자 웹 승인 -> 학습자 앱 알림 및 콘텐츠 업데이트의 전체 플로우 테스트
*   **4.2 최적화 및 안정성 확보**
    *   [ ] Redis 캐시를 활용한 API 응답 속도 개선
    *   [ ] Docker Compose 환경의 서비스 간 의존성(Depends_on) 및 헬스체크 튜닝

---

## 4. 데이터베이스 스키마 설계 요약 (Core Entities)

*   **`member`**: id, email, password, role(ADMIN/LEARNER), job_category, created_at
*   **`curriculum`**: id, title, description, target_job_category, is_active
*   **`lesson`**: id, curriculum_id, order_index, title, content_markdown (최신본)
*   **`content_history`**: id, lesson_id, previous_markdown, new_markdown, changed_law_info, approved_by, approved_at
*   **`approval_request`**: id, lesson_id, ai_generated_markdown, diff_summary, status(PENDING/APPROVED/REJECTED), created_at

---

## 5. 서비스 간 API 연동 규격 (Internal)

1.  **AI Engine -> Spring Boot (Webhook)**
    *   `POST /api/internal/content/proposed`
    *   Body: `{ "lessonId": 123, "newContent": "...", "diffSummary": "...", "lawReference": "..." }`
2.  **Spring Boot -> AI Engine (Trigger/Test)**
    *   `POST /generate-content` (현재 `main.py`에 존재)

---

## 6. 핵심 리스크 및 마일스톤

*   **리스크 1: AI 환각(Hallucination)에 의한 잘못된 법령 해석**
    *   **대책**: Phase 1의 검증 노드(Validation Node) 프롬프트를 엄격히 통제하며, Phase 3에서 관리자 화면의 Diff Viewer 가독성을 극대화하여 인적 검토를 용이하게 함.
*   **리스크 2: 초기 프론트엔드 구축 공수 부족**
    *   **대책**: Flutter Web과 App의 공통 UI 컴포넌트(Markdown Renderer)부터 최우선 개발하여 중복 작업을 방지.
*   **마일스톤**:
    *   `M1` (Week 2): AI Engine이 법령 변화를 감지하고 마크다운 초안을 생성해내는 PoC 완료
    *   `M2` (Week 4): 백엔드 API 연동 완료 및 Postman 기반 승인 프로세스 테스트
    *   `M3` (Week 6): Flutter 통합 및 데모 시나리오 완수
