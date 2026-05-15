# [기능 명세서] EverLaw Edu: AI 에이전트 기반 자율 갱신형 컴플라이언스 솔루션

## 1. 문서 개요 (Document Overview)
본 문서는 "EverLaw Edu" 제품요구사항정의서(PRD)를 바탕으로, 시스템 구현을 위한 상세 기능 및 기술적 요구사항을 정의한 기능 명세서(Functional Specification)입니다. 개발팀, QA팀 및 시스템 운영자가 본 솔루션의 아키텍처와 세부 기능을 이해하고 구현하는 데 목적이 있습니다.

---

## 2. 시스템 아키텍처 개요 (System Architecture Overview)
EverLaw Edu는 실시간 법령 변화에 대응하여 교육 콘텐츠를 자동 갱신하는 지능형 시스템입니다. Microservices Architecture(MSA)를 기반으로 확장성과 유지보수성을 극대화하며, 다음과 같은 주요 컴포넌트로 구성됩니다.

1. **Spring Boot (Back-end)**: 비즈니스 로직 처리, API 게이트웨이, 데이터 트랜잭션(JPA) 및 콘텐츠 버전 관리.
2. **Python 기반 AI 에이전트 (AI Engine)**: **FastAPI**와 **LangGraph**를 활용하여 에이전틱 워크플로우 구현.
    - **LLM**: Google Gemini 3.1 Flash-Lite (초저지연 고효율 에이전틱 모델)
    - **Embedding**: bge-m3 (Ollama 로컬 인퍼런스)
3. **Redis (Cache & Message Broker)**: 비동기 작업 큐 처리, LLM 응답 데이터 캐싱 및 실시간 알림 상태 관리. (Mac Mini 로컬 호스팅)
4. **PostgreSQL (pgvector)**: 정형 데이터 및 RAG를 위한 벡터 데이터 통합 저장소. (Mac Mini 로컬 호스팅)
5. **Flutter (Front-end)**: 관리자용 웹 대시보드 및 학습자용 멀티 플랫폼(Android, iOS, Web) 클라이언트 제공.

---

## 3. 핵심 기능 명세 (Core Functional Specifications)

### 3.1 AI 에이전트 워크플로우 시스템 (AI Agent Workflow System)
법령의 변화를 감지하고 새로운 콘텐츠를 생성하기 위한 핵심 파이프라인으로, **LangChain**의 체이닝 기술을 활용하여 구현합니다.

*   **[F-1] 실시간 법령 모니터링 (Law Scanner Module)**
    *   **기능 요약**: 주기적으로 국가법령정보센터 API 및 주요 부처 RSS 피드를 수집하여 법령 개정안 감지.
    *   **상세 요건**:
        *   스케줄러 기반 배치 작업 수행 및 **Redis 기반 작업 큐**를 통한 분산 처리 준비.
        *   수집된 법령 데이터의 해시값을 비교하여 변경 사항 식별.
        *   공공 API 장애 시 백업 크롤링 엔진으로 자동 전환 (Failover).

*   **[F-2] 지능형 차분 분석 엔진 (Impact Analysis Engine)**
    *   **기능 요약**: 감지된 개정 법령이 기존 교육 커리큘럼(텍스트, 이미지, 퀴즈 등)에 미치는 영향을 분석.
    *   **상세 요건**:
        *   기존 커리큘럼의 메타데이터와 신규 법령 간의 의존성 매핑.
        *   영향도 수준(High/Medium/Low) 분류 알고리즘 적용.

*   **[F-3] RAG 기반 자율 콘텐츠 생성기 (Autonomous Content Generator)**
    *   **기능 요약**: 개정된 법령을 바탕으로 신규 강의안 및 퀴즈 콘텐츠를 자동 생성.
    *   **상세 요건**:
        *   벡터 DB(Vector DB)를 활용한 정확한 문맥 검색(Retrieval).
        *   **Redis 캐싱**을 활용한 동일 법령에 대한 중복 생성 방지 및 응답 속도 최적화.
        *   마크다운(Markdown) 포맷으로 구조화된 학습 자료 생성.
        *   퀴즈 생성 시 난이도 조절 및 해설 포함.

*   **[F-4] AI 자가 검증 시스템 (Auto-Validation System)**
    *   **기능 요약**: 생성된 콘텐츠가 개정 법령에 정확히 부합하는지 교차 검증.
    *   **상세 요건**:
        *   서로 다른 프롬프트 또는 모델(Cross-model)을 활용한 사실 관계 확인(Fact-checking).
        *   환각(Hallucination) 의심 지수 산출 및 경고 플래그 생성.

### 3.2 관리자 시스템 (Admin System)
인사/노무 담당자가 AI의 제안을 검토하고 통제하는 웹 기반 대시보드입니다.

*   **[A-1] 콘텐츠 비교 및 승인 워크플로우 (Side-by-Side Review)**
    *   **기능 요약**: 기존 콘텐츠와 AI가 생성한 신규 콘텐츠의 차이를 직관적으로 비교하고 배포 승인.
    *   **상세 요건**:
        *   변경 전/후 텍스트 하이라이트 UI (Git Diff 스타일) 제공.
        *   '승인', '반려', '수정 후 승인' 액션 버튼 제공 (Human-in-the-loop 강제 적용).
        *   승인 시 즉각적인 릴리스 처리 및 전체 학습자 대상 배포 트리거.

*   **[A-2] 교육 이력 및 버전 관리 (Versioning & History)**
    *   **기능 요약**: 과거 교육 콘텐츠와 학습 이력을 영구 보존하여 법적 감사(Audit) 대비.
    *   **상세 요건**:
        *   JPA Auditing을 활용한 콘텐츠 수정 이력 트래킹.
        *   학습자가 이수한 교육 콘텐츠의 특정 버전(Snapshot) 매핑 저장.

### 3.3 사용자 시스템 (Learner System)
임직원이 최신 법정 의무 교육을 수강하는 프론트엔드 환경입니다.

*   **[U-1] 동적 콘텐츠 뷰어 (Dynamic UI Renderer)**
    *   **기능 요약**: AI가 생성한 마크다운 기반 자료를 모바일 및 웹에 최적화하여 렌더링.
    *   **상세 요건**:
        *   기기 해상도에 맞춘 반응형 UI 렌더링.
        *   텍스트, 이미지, 퀴즈 등 다양한 컴포넌트 동적 파싱.

*   **[U-2] 맞춤형 푸시 알림 (Personalized Notification)**
    *   **기능 요약**: 학습자 본인의 직무와 직접적으로 연관된 법령이 개정되었을 때만 알림 발송.
    *   **상세 요건**:
        *   사용자 프로필(직무, 부서)과 변경된 법령 카테고리 매칭 로직 적용.
        *   FCM(Firebase Cloud Messaging) 등 푸시 인프라 연동.

---

## 4. 비기능 요구사항 (Non-Functional Requirements)

1.  **성능 (Performance)**:
    *   법령 개정 확정 고시 후 **24시간 이내**에 AI 콘텐츠 생성 및 검증 절차 완료.
    *   **Redis 캐싱** 및 비동기 파이프라인 최적화를 통해 사용자 요청에 대한 Zero-latency 수준의 응답성 확보.
    *   MSA 컴포넌트(Spring Boot - AI Engine) 간 통신 지연 최소화를 위한 최적화.
2.  **신뢰성 및 안전성 (Reliability & Safety)**:
    *   **Zero-Hallucination 지향**: AI 생성 결과물은 반드시 관리자의 최종 승인(Human-in-the-loop)을 거쳐야만 배포 가능하도록 정책적 시스템 락(Lock) 적용.
    *   외부 API 장애 시나리오 대비 백업 크롤러 자동화.
3.  **확장성 (Scalability)**:
    *   Phase 2, 3 로드맵 대응을 위해 사규 문서 업로드 및 다국어 확장이 용이한 DB 스키마 설계.
    *   **FastAPI**의 비동기 구조와 **LangChain**의 모듈화된 컴포넌트를 통해 AI 서비스의 높은 확장성 및 유연성 확보.
    *   Flutter 기반 단일 코드베이스로 유지보수 비용 최소화.

---

## 5. 단계별 상세 개발 태스크 리스트 (Detailed Task List)

본 리스트는 프로젝트의 기술적 맥락과 세부 단계를 명시하여, 개발 세션이 바뀌더라도 연속성을 유지할 수 있도록 작성되었습니다.

### Phase 1: 인프라 및 AI 에이전트 코어 (Infrastructure & AI Core)
- [x] **T1.1. 컨테이너 기반 인프라 구축 (Mac Mini)**
    - [x] Docker Compose 구성 (Ollama: 11439, Postgres: 5437, Redis: 6384)
    - [x] pgvector 확장 플러그인이 포함된 PostgreSQL 이미지 설정
- [x] **T1.2. AI Engine (Python/FastAPI) 환경 및 스켈레톤**
    - [x] `uv`를 활용한 의존성 관리 및 가상환경 설정
    - [x] `main.py`: `/analyze-impact`, `/generate-content` 엔드포인트 설계
    - [x] `.env` 설정 (Google API Key, bge-m3 모델 설정)
- [x] **T1.3. LangGraph 기반 RAG 워크플로우 구현**
    - [x] `rag_engine.py`: **LangGraph**를 활용한 Retrieve-Generate 에이전트 구축
    - [x] **bge-m3**(Ollama) 임베딩 및 **Gemini 3.1 Flash-Lite** 연동 테스트
    - [x] 상태 관리(TypedDict) 기반의 에이전틱 파이프라인 구성
- [ ] **T1.4. 실시간 법령 수집기 (Law Scanner) 개발**
    - [ ] 국가법령정보센터 API 및 **legalize-kr(Github)** 데이터 연동 모듈 개발
    - [ ] Git 커밋 이력을 활용한 법령 개정 차분(Delta) 데이터 자동 추출 로직 구현
    - [ ] Redis 기반의 중복 수집 방지(Hash 비교) 및 변경 탐지 시스템 구축
- [ ] **T1.5. 지능형 영향도 분석(Impact Analysis) 고도화**
    - [ ] **Git Diff 기반** 변경 조항 핀포인트 식별 알고리즘 개발
    - [ ] 개정 조항과 교육 커리큘럼 간의 지능형 의존성 매핑(Gemini 3.1 활용)

### Phase 2: 백엔드 및 관리 서비스 (Back-end & Admin Services)
- [ ] **T2.1. Spring Boot 기반 비즈니스 서버 구축**
    - [ ] JPA 기반 데이터 도메인 설계 (Law, Curriculum, Member, History)
    - [ ] AI Engine과의 통신을 위한 REST Client 또는 gRPC 설정
- [ ] **T2.2. 교육 콘텐츠 버전 및 감사 시스템**
    - [ ] JPA Auditing 및 스냅샷 저장을 통한 법적 감사(Audit) 추적 기능
    - [ ] 교육 이수 당시의 콘텐츠 버전을 영구 보존하는 로직 구현
- [ ] **T2.3. 승인 워크플로우(HITL) 백엔드**
    - [ ] 관리자 승인 전까지 배포를 차단하는 상태 제어 로직
    - [ ] Redis Pub/Sub을 활용한 실시간 배포 트리거 구현

### Phase 3: 프론트엔드 및 사용자 경험 (Front-end & UX)
- [ ] **T3.1. Flutter 관리자 대시보드 (Web)**
    - [ ] Side-by-Side 비교 뷰어 (Git Diff 스타일의 텍스트 하이라이팅)
    - [ ] 콘텐츠 승인/반려/수정 워크플로우 UI 구현
- [ ] **T3.2. Flutter 학습자 멀티 플랫폼 앱 (Android/iOS/Web)**
    - [ ] 마크다운(Markdown) 기반 학습 자료 동적 렌더링 엔진
    - [ ] AI 생성 퀴즈 인터페이스 및 결과 피드백 시스템
- [ ] **T3.3. 맞춤형 알림 서비스**
    - [ ] FCM(Firebase Cloud Messaging) 연동 및 직무 기반 타겟팅 발송

### Phase 4: 안정화 및 배포 (Stabilization & Deployment)
- [ ] **T4.1. AI 자가 검증(Auto-Validation) 시스템**
    - [ ] 생성된 결과물의 법적 근거를 역으로 체크하는 교차 검증 로직
- [ ] **T4.2. 통합 테스트 및 성능 최적화**
    - [ ] 법령 고시 후 24시간 이내 업데이트 성능 지표 달성 확인
    - [ ] 부하 테스트 및 캐싱 전략(Redis) 최적화
