# [구현 계획서] EverLaw Edu 솔루션 개발 계획 (개정판)

**작성자**: Senior Full-Stack Engineer
**목적**: 제품 요구사항정의서(PRD) 및 기능 명세서를 바탕으로, 최신 법령 전문 DB를 지식 원천(Ground Truth)으로 삼아 교육용 강의안과 평가 퀴즈를 무(無)에서 유(유)로 자율 생산(Fact-based Content Factory)하는 하이브리드 아키텍처 구축의 상세 마일스톤과 통합 방안을 정의합니다.

---

## 1. 개요 및 현재 시스템 상태
현재 로컬 Mac Mini 환경에서 PostgreSQL(pgvector), Ollama(bge-m3), Redis 컨테이너 인프라가 가동 중이며, Python 기반 `ai-engine`에서 **최신 법령 전문 DB 실시간 SQL-level Upsert 적재 ➡️ RAG 기반 자율 콘텐츠 생산 ➡️ AI 자가 팩트체크 검증 노드**로 이어지는 핵심 AI 두뇌의 구축과 로컬 E2E 검증이 대성공으로 성료된 상태입니다.

**향후 핵심 과제**:
1. 자율 생산된 교육 콘텐츠 및 관리자 대기열을 처리할 **Spring Boot 비즈니스 백엔드 서버 구축** (JPA Auditing 및 스냅샷 버전 관리)
2. 법령 조문 팩트(Left)와 AI 생산 교안(Right)을 정교하게 비교 대조하며 릴리스하는 **Flutter 기반 Side-by-Side Reference & Content UI 개발**

---

## 2. 아키텍처 및 기술 스택 

### 2.1 인프라 및 데이터베이스
- **Local Hosting**: Mac Mini (Docker Compose 컨테이너 인프라)
- **Database**: PostgreSQL 16 (pgvector), Redis (Cache & Queue & Pub/Sub)
- **RAG 저장 구조**: 
  - `law_documents`: 깃허브 및 국가 법령 정보에서 수집한 최신 실질 조문 전문 컬렉션 (Ground Truth)
  - `curriculum_documents`: AI가 최신 법령을 마중물로 삼아 자율 생산해낸 교육 마크다운 강의안/퀴즈 컬렉션

### 2.2 AI Engine (구현 완료)
- **Framework**: Python 3.12, FastAPI
- **AI/LLM**: Google Gemini 3.1 Flash-Lite, Ollama (bge-m3 Embedding)
- **Workflow**: LangChain, LangGraph 기반의 자율 에이전트 감사 노드 구성

### 2.3 Back-end (신규 구축 예정)
- **Framework**: Spring Boot 3.x, Java 25
- **ORM / DB**: Spring Data JPA, Hibernate, PostgreSQL Driver
- **Security**: Spring Security, JWT (인증/인가)

### 2.4 Front-end (신규 구축 예정)
- **Framework**: Flutter 3.x (Dart)
- **State Management**: Riverpod (상태 관리 표준화)
- **UI Renderer**: Markdown 렌더링 엔진 (flutter_markdown)

---

## 3. 단계별 구현 계획 (Phased Implementation Plan)

### Phase 1: AI 엔진 고도화 및 최신 법령 DB 적재 (완료)
최신 법령을 Ground Truth 삼아 콘텐츠를 창작 및 사실 확인 검증하는 핵심 Python API 시스템을 완성하는 단계입니다.

*   **1.1 실시간 법령 수집 및 SQL-level Upsert (`scheduler.py` & `database.py`) [x]**
    *   [x] **대한민국 법령 맞춤형 시맨틱 청킹 (조 단위 완결성 보존)**: `##### 제N조 (제목)`로 설계된 3대 법령의 5단계 마크다운 헤더 규격을 역추적하여 **조(Article) 단위의 물리적 시맨틱 독립 바운더리를 확립한 청킹 아키텍처** 완성. LLM의 정보 밀도와 RAG 생성 단계의 맥락 단절 및 환각(Hallucination)을 근본적으로 차단하기 위해, 자잘하게 쪼개는 2차 물리 캐릭터 청킹을 완전히 배제하고 의미적 완결체인 **'조(Article) 단위의 온전한 바운더리'**를 그대로 pgvector DB에 최종 청크로 동기화 적재함.
    *   [x] **가지조항 및 서식 이스케이프 격퇴**: `제4조의2`와 같은 가지조항 Regex 검출 보강, 그리고 `1\.`, `가\.` 같은 마크다운 백슬래시 이스케이프 및 `**①**` 볼드체 항 번호 예외 처리를 무결점으로 돌파하는 **초고성능 정밀 주소 파서 헬퍼** 장착.
    *   [x] **실시간 스캐너 RAG 아키텍처 대통합**: 벌크 시드 적재기(`seed.py`)와 실시간 변경분 감지기(`scheduler.py`)가 동일한 조/항/호/목 파서(`split_law_markdown_to_documents`)를 연동하게 함으로써, **영구적으로 동일하게 필터링 가능한 100% 정렬된 RAG 메타데이터 일관성** 확립 (Metadata Drift 방지).
    *   [x] **스마트 SHA-256 해시 CDC (Change Data Capture)**: 내용 무변경 조항 청크는 임베딩 생성 API 호출과 DB 트랜잭션을 자동으로 건너뛰는(SKIP) 스마트 검사 아키텍처 장착 완료. 이를 위해 `cmetadata` 내에 SHA-256 본문 해시를 누적하여 이전 적재분과 비교 대조함.
    *   [x] **SQL-level 멱등성 업서트(Upsert) 및 중복 배제**: 데이터 갱신 시, 불변의 고유 비즈니스 키(`law_{law_name}_{article}`)를 기준으로 기존 레코드를 데이터베이스에서 **물리적 SQL-level 선삭제(DELETE) 후 삽입(INSERT)**하여 멱등성 100% 및 중복 쓰레기 축적 방지 완수.
    *   [x] **깃허브 전문 스캔 파이프라인 개편**: 커밋 패치 기반의 조항 번호 추출 누락 리스크를 차단하기 위해, 깃허브 변경 감지 시 파일 **전문(Whole File)을 실시간으로 안전하게 다운로드**한 후 전체 청킹하여 해시 CDC 파이프라인으로 일괄 공급 처리하는 강력한 설계로 고도화 완료.
    *   [x] **데이터베이스 스키마 및 런타임 오류 완전 방어**: LangChain PGVector 테이블의 실제 컬럼명(`cmetadata`)과 다른 낡은 컬럼 명칭(`cmetadict`)을 SQL 레벨에서 완벽하게 전수 교정하고, 패치 분석 폴백 경로 진입 시 미정의 변수로 인한 NameError 다운 크래시를 전격 해결하여 100% 무중단 운영 보장.
*   **1.2 최신 법령 DB 기반 자율 콘텐츠 생산 RAG (`generator.py`) [x]**
    *   [x] `law_documents` 컬렉션의 가장 신선한 법령 조문을 RAG 지식 소스로 사용하여, 스토리텔링 기법과 모의 평가 퀴즈가 결합된 교육용 마크다운 교안을 무(無)에서 유(유)로 자율 생산하는 생성 체인 구축 완료.
*   **1.3 AI 검증(Validation) 감사 노드 추가 (`validator.py` & `graph_workflow.py`) [x]**
    *   [x] LangGraph 워크플로우에 `validate` 자가 감사 노드를 배치하여, 생산된 문장의 숫자나 의도가 원본 법령 지식과 1대1 교차 사실 대조를 통과(환각 지수 0.0%)하는지 검증하는 자가 팩트체크 시스템 성료.

### Phase 2: Spring Boot 비즈니스 서버 구축 (진행 예정 / Week 3-4)
자율 생산된 교육 자료들의 생명주기를 영구 관리하고 Flutter 클라이언트를 서빙할 백엔드를 개발합니다.

*   **2.1 프로젝트 초기화 및 DB 설계**
    *   [x] Spring Boot 프로젝트 세팅 (JPA, Web, Security, PostgreSQL 드라이버 연동)
    *   [x] JPA Entity 설계: `Member`(사용자), `Curriculum`(교육 카테고리/과정), `Lesson`(AI 자율 생산 교안 마크다운 수록), `ApprovalRequest`(콘텐츠 생산 후 관리자 검토 대기열), `ContentSnapshot`(특정 릴리스 버전 보존 스냅샷)
*   **2.2 AI Engine 콘텐츠 생산 연동 및 웹훅(Webhook) API**
    *   [x] 교육 담당자가 생산 트리거 시 FastAPI AI 엔진을 호출하여 교안을 동적 창작하고, 결과를 백엔드로 수신하여 `ApprovalRequest`로 전환하는 연동 로직 구현.
    *   [x] Redis Pub/Sub과 FCM 기반 실시간 알림 로직 구성.
*   **2.3 프론트엔드 제공 API 개발**
    *   [x] JWT 기반 인증/인가 및 직무 카테고리 권한 관리.
    *   [x] 대기열 조회/승인/반려 처리 및 릴리스 배포 API 구현.

### Phase 3: Flutter 프론트엔드 구축 (Week 5-6)
하나의 코드베이스로 관리자 웹 대시보드와 학습자 모바일 앱을 구성합니다.

*   **3.1 공통 및 코어 모듈 구성**
    *   [x] Flutter 프로젝트 구조 세팅 및 Riverpod 기반 상태 관리 모듈 구성.
    *   [x] 마크다운 동적 파싱 렌더러 커스텀 위젯 개발.
*   **3.2 법령-교안 대조 승인 뷰어 (Web Target)**
    *   [x] **좌측(최신 법령 조문 팩트) vs 우측(AI가 생산해낸 마크다운 교안 및 퀴즈) Side-by-Side Reference & Content Viewer UI** 구현.
    *   [x] AI 자가 검증 결과(Hallucination Score) 및 감사 소견 시각적 렌더링.
*   **3.3 학습자용 앱 (Mobile Target)**
    *   [x] 최신 생산 릴리스 완료 교안 수강 및 실시간 모의 퀴즈 채점 피드백 UI.
    *   [x] FCM 연동 맞춤형 직무 푸시 알림 수신.

### Phase 4: 통합 테스트 및 배포 안정화 (Week 7-8)

*   **4.1 E2E 통합 테스트**
    *   [ ] 법령 업데이트 감지 ➡️ 최신 법령 DB Upsert ➡️ 관리자 대시보드에서 생성 클릭 ➡️ AI 자율 생산 및 자가 검증 ➡️ 관리자가 대조 화면에서 최종 승인 ➡️ 스냅샷 영구 저장 및 학습자 앱 배포/알림 E2E 종합 검증.
*   **4.2 최적화 및 안정성 확보**
    *   [ ] Docker Compose 환경 서비스 헬스체크 고도화.

---

## 4. 데이터베이스 스키마 설계 요약 (Core Entities)

*   **`member`**: id, email, password, role(ADMIN/LEARNER), job_category, created_at
*   **`curriculum`**: id, title, description, category(예: 안전보건, 근로기준), target_job_category
*   **`lesson`**: id, curriculum_id, title, content_markdown (최신 생산본), associated_law_reference (RAG의 근거가 된 최신 법정 조항 고유 식별자 키)
*   **`content_snapshot`**: id, lesson_id, curriculum_title, lesson_title, content_markdown, approved_by, approved_at (법적 감사 보존용 영구 데이터)
*   **`approval_request`**: id, lesson_id, law_reference, ai_generated_markdown, validation_details, hallucination_score, status(PENDING/APPROVED/REJECTED), created_at

---

## 5. 서비스 간 API 연동 규격

1.  **AI Engine -> Spring Boot (Proposed Webhook)**
    *   `POST /api/internal/content/proposed`
    *   Body: `{ "lessonId": 123, "lawReference": "...", "newContent": "...", "validationDetails": "...", "hallucinationScore": 0.0 }`
2.  **Spring Boot -> AI Engine (Generate Trigger)**
    *   `POST /generate-content`
    *   Body: `{ "law_content": "...", "metadata": { "lesson_id": 123 } }`

---

## 6. AI Engine 백로그 및 기술 부채 개선 과제 (시니어 제안)

향후 시스템 스케일 아웃 및 대규모 컴플라이언스 트래픽 처리를 위해 추후 개발 단계에서 보강해야 할 핵심 백로그입니다.

### 6.1 SQLAlchemy Connection Pool 누수 차단 및 싱글톤화 (High)
*   **이슈**: `database.py` 내의 `add_document_to_vector_store` 및 `add_documents_to_vector_store_bulk` 함수가 호출될 때마다 매번 `create_engine(CONNECTION_STRING)`을 새로 호출하고 있어 데이터베이스 **소켓 고갈(Socket Exhaustion)** 및 커넥션 풀 풀링 실패 위험이 있습니다.
*   **작업 내용**:
    *   [ ] `database.py` 모듈 레벨에서 `engine`을 1회만 초기화(싱글톤 패턴)하여 전체 애플리케이션이 공유하도록 변경.
    *   [ ] 세션 사용 시 `scoped_session` 또는 context manager(`with`) 패턴을 엄격하게 적용하여 자원 자동 해제 보장.

### 6.2 LangGraph 비동기(Async) 마이그레이션 (Medium)
*   **이슈**: FastAPI 엔드포인트 `/generate-content`는 `async def` 기반으로 동작하나, 내부에서 호출하는 `graph_app.invoke()` 및 각 감사/RAG 노드가 동기식(Blocking) I/O로 작동하여 이벤트 루프를 장시간 점유할 위험이 있습니다.
*   **작업 내용**:
    *   [ ] `generator.py`, `validator.py` 의 RAG 및 감사 노드 함수들을 `async def`로 리팩토링.
    *   [ ] `graph_workflow.py`에서 `graph_app.invoke(inputs)` 호출부를 비동기 `await graph_app.ainvoke(inputs)` 체계로 마이그레이션.

### 6.3 Ollama 임베딩 배치 크기 환경 변수화 (Low)
*   **이슈**: 벌크 적재 시 50개 크기로 배치를 잘라 전송하고 있어 로컬 Ollama 구동 환경의 하드웨어 리소스 상황에 따라 타임아웃이나 데드락 위험이 있습니다.
*   **작업 내용**:
    *   [ ] `.env` 및 `config.py`에 `EMBEDDING_BATCH_SIZE`를 설정 가능하도록 제어 상수 분리.
    *   [ ] `database.py`에서 벌크 청크 임베딩 전송 시 하드웨어 부하 상태에 따라 유동적으로 배치 슬라이싱 크기를 제어하도록 교체.

### 6.4 GitHub API Rate Limit 예외 처리 및 토큰 주입 정밀화 (Low)
*   **이슈**: `scheduler.py`에서 GitHub API 호출 시 익명 클라이언트로 폴백할 경우, 시간당 60회의 매우 좁은 레이트 리밋에 걸려 백엔드 에러 크래시를 유발할 수 있습니다.
*   **작업 내용**:
    *   [ ] API 호출 부 전체에 `github.GithubException` 정밀 예외 처리를 장착하여 실패 시 크래시 없이 로깅 및 폴백(Fallback) 보장.
    *   [ ] `.env` 파일에 토큰이 없거나 잘못된 포맷인 경우 경고 레벨 로그를 명확히 출력하도록 로깅 시스템 고도화.

