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

## 🎯 [UX 개편 제안] 이론 강좌 탭 제거 및 오답 노트 전면 배치

사용자의 지적 에너지를 문제 풀이 및 복습에 집중시키고 UX 복잡도를 최소화하기 위해 **"이론 강좌" 탭을 과감히 제거하고 "오답 노트"를 메인 탭으로 승격**합니다.

### User Review Required
> [!IMPORTANT]
> **메인 네비게이션 변경 사항**: 하단 탭바(BottomNavigationBar)가 `[모의고사, 이론 강좌]`에서 `[모의고사, 오답 노트]`로 변경됩니다. 기존의 이론 강좌(Lesson) 화면은 접근 경로가 사라지며, 추후 필요 시 모의고사 오답 해설에서 인라인으로만 참조되거나 완전히 폐기됩니다. 이 변경을 진행해도 될까요?

### Proposed Changes
#### [MODIFY] [main_tab_screen.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/main/views/main_tab_screen.dart)
- `LessonListScreen` 임포트 및 탭 아이템 제거.
- `IncorrectNoteScreen` 임포트 및 탭 아이템 추가.
- 바텀 네비게이션 UI 텍스트 및 아이콘 변경 (`이론 강좌` -> `오답 노트`).

#### [DELETE] [lib/features/lesson](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/lesson)
- 더 이상 사용되지 않는 이론 강좌 뷰 및 관련 모듈을 삭제합니다.

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
    *   [ ] **[U-7] 오답노트 개별 삭제 및 취약 지수 연동 API 개발**:
        - `DELETE /api/incorrect-notes/{id}` 엔드포인트 구현 (오답 이력 DB Soft-Delete 처리).
        - 삭제 사유가 학습 완수(Mastery)인 경우, 연관 테이블 `member_weakness_index`를 갱신하여 해당 조항의 취약 지수를 차감하는 안전 구역 보정 비즈니스 로직 구현.
    *   [ ] **[U-8] 연속 정답 추적 및 지능형 자동 졸업 비즈니스 로직 개발**:
        - 퀴즈 채점 제출 API (`POST /api/quizzes/submit`) 동작 시, 사용자의 해당 `law_reference` 대상 최근 퀴즈 제출 이력을 실시간 쿼리하여 **연속 3회 정답 여부 판정**.
        - 조건 충족 시 해당 사용자의 해당 조항 연계 모든 구버전 오답 데이터를 `is_archived = true`로 일괄 자동 아카이빙 업데이트 처리.
        - `member_weakness_index`의 `weakness_score`를 즉시 0점(완전 극복)으로 초기화 청산하는 트랜잭션 로직 구현.

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
    *   [x] **[U-3] 4지선다형 스토리텔링 퀴즈 및 인터랙션 구현**:
        - 사용자가 보기를 선택했을 때 즉각적인 색상 피드백(정/오답 구분) 제공.
        - 정답일 경우, **0.8초~1초의 모션 딜레이**를 보장한 후 다음 퀴즈 카드로 갱신(State-Change) 렌더링.
    *   [ ] **[UX 개편] 이론 강좌 탭 제거 및 오답 노트 전면 배치 구현**:
        - 기존 하단 탭의 '이론 강좌'를 완전히 제거하고, 그 자리에 '오답 노트'를 전면 승격하여 문제 풀이 중심의 코어 루프 강화.
        - 불필요해진 `lesson` 프론트엔드 모듈 및 라우팅 정리.
    *   [x] **[U-4] 오답 복습용 해설 패널 및 컨텍스트 연동 인라인 AI 챗봇 개발**:
        - 오답 발생 시, 문제 하단에 상세 해설 패널 슬라이딩 오픈 애니메이션 구현.
        - 해설 패널 하단에 인라인 AI 도우미 채팅창 배치.
        - 채팅창 대화 발송 시, 현재 틀린 문제의 컨텍스트(`question`, `options`, `selectedIndex`, `answerIndex`, `lawReference`)를 API 본문 페이로드에 자동 바인딩하여 백엔드로 전달하는 로직 구축.
    *   [x] **[U-5] 메인 하단 탭(Bottom Navigation) 오답노트 전면 배치 및 로컬 영속화 구현**:
        - 기존 '이론 강좌' 탭을 제거하고, 메인 하단 탭에 "오답 노트"를 전면 배치.
        - 로컬 디바이스 저장소에서 오답 데이터를 로드하여 목록 및 대화 히스토리를 노출하는 **오답노트 복습 전용 라우팅 및 뷰(View) 개발**.
    *   [x] **[U-7] 오답노트 개별 문제 삭제 및 아카이빙 (Learner Deletion) 구현**:
        - 오답노트 개별 퀴즈 카드 우상단에 "삭제/완료" 버튼 탑재 및 클릭 시 화면 페이드아웃 애니메이션 적용.
        - 로컬 저장소 즉시 삭제(Delete) 트랜잭션 수행 및 서버 삭제 동기화 API 연동 처리.
    *   [x] **[U-8] 지능형 자동 졸업 축하 위젯(Mastery Card) 및 연출 UI 개발**:
        - 3회 연속 정답 달성 시 화면 최상단에 **"개념 완벽 정복(Mastery) 및 자동 졸업"** 안내 팝업 및 축하 애니메이션(Lottie) 탑재.
        - 오답 리스트 동적 리프레시(아카이빙에 따른 리스트 아웃) 연동 구현.
    *   [x] **[U-6] 지능형 개인 맞춤형 변형 퀴즈 클리닉(Adaptive AI Quiz Clinic) 개발**:
        - 학습용 뷰 내에 "취약점 극복 훈련" 진입 컴포넌트 및 개인별 취약 조항 점수 상태 바(ProgressBar) 탑재.
        - API 호출을 통해 온더플라이로 수신된 실시간 변형 퀴즈 팩 렌더링 카드 및 오답노트 리라우팅 연동 뷰 구현.

### Phase 4: 통합 테스트 및 배포 안정화 (Week 7-8)

*   **4.1 E2E 통합 테스트**
    *   [ ] 법령 업데이트 감지 ➡️ 최신 법령 DB Upsert ➡️ 관리자 대시보드에서 생성 클릭 ➡️ AI 자율 생산 및 자가 검증 ➡️ 관리자가 대조 화면에서 최종 승인 ➡️ 스냅샷 영구 저장 및 학습자 앱 배포/알림 E2E 종합 검증.
    *   [ ] 퀴즈 오답 발생 ➡️ 로컬 저장소 즉각 영속화 ➡️ AI 도우미 연동 ➡️ 오답노트 화면 내 데이터 정합성 유지 검증.
    *   [ ] 오답노트 문제 삭제 ➡️ 로컬 즉시 삭제 및 서버 DELETE API 비동기 동기화 ➡️ 서버 DB 취약 지수(`member_weakness_index`) 차감 보정 반영 E2E 검증.
    *   [ ] **특정 법령 조항 변형 문제 연속 3회 정답 ➡️ 서버의 아카이빙 로직 발동 (`is_archived = true`) ➡️ 로컬 동기화 및 뷰 자동 아웃 ➡️ 취약 지수 0점 리셋 연계 E2E 검증.**
*   **4.2 최적화 및 안정성 확보**
    *   [ ] Docker Compose 환경 서비스 헬스체크 고도화.

---

## 4. 데이터베이스 스키마 설계 요약 (Core Entities)

*   **`member`**: id, email, password, role(ADMIN/LEARNER), job_category, created_at
*   **`curriculum`**: id, title, description, category(예: 안전보건, 근로기준), target_job_category
*   **`lesson`**: id, curriculum_id, title, content_markdown (최신 생산본), associated_law_reference (RAG의 근거가 된 최신 법정 조항 고유 식별자 키)
*   **`content_snapshot`**: id, lesson_id, curriculum_title, lesson_title, content_markdown, approved_by, approved_at (법적 감사 보존용 영구 데이터)
*   **`approval_request`**: id, lesson_id, law_reference, ai_generated_markdown, validation_details, hallucination_score, status(PENDING/APPROVED/REJECTED), created_at
*   **`quiz_bank`**: id (UUID, PK), lesson_id (FK), law_reference (지정 법령 조항 명칭), question (스토리텔링 지문 본문), options (JSON 배열형 4지선다 보기 항목), answer_index (정답 인덱스 0~3), hint, explanation (원본 법 조문 및 법리 근거 해설), created_at, updated_at (벌크 생성 및 핫스왑의 타겟 통합 퀴즈 DB)
*   **`member_weakness_index`**: id (PK), member_id (FK), law_reference (대상 법령 조항), incorrect_count (누적 오답 횟수), weakness_score (취약 지수 점수, 퀴즈 극복 통과 시 차감 갱신), last_updated_at
*   **`member_incorrect_note` (Server DB)**: id (PK), client_uuid (로컬 동기화용 고유 식별자), member_id (FK), quiz_id (FK), law_reference, selected_index, is_archived (자동 졸업 여부), is_deleted (Soft-delete 처리 플래그), incorrect_at, created_at, updated_at (클라이언트의 오답 내역을 동기화하여 저장하는 서버 측 통합 오답 레코드)
*   **`client_incorrect_note (Client Local Storage)`**: 틀린 문제 및 대화 기록을 보존하기 위해 기기 로컬 디바이스에 직렬화하여 저장할 핵심 스키마 규격입니다. (Hive/SQLite 등 지원)
    ```json
    {
      "id": "String (UUID, 로컬 기록 고유 식별자)",
      "quizId": "String (UUID, 서버 측 원본 퀴즈 식별자)",
      "question": "String (스토리텔링 질문 본문)",
      "options": "List<String> (4지선다 보기 항목 배열)",
      "answerIndex": "Int (0~3 사이의 정답 인덱스)",
      "selectedIndex": "Int (학습자가 선택한 오답 인덱스)",
      "hint": "String (생성된 힌트 문구)",
      "explanation": "String (상세 법적 근거 해설)",
      "lawReference": "String (근거 법령 이름 및 관련 조항 정보)",
      "incorrectAt": "String (ISO-8601 타임스탬프, 틀린 시점)",
      "isSynced": "Boolean (서버 동기화 완료 여부 플래그, 로컬 아웃박스 패턴 제어용)",
      "isArchived": "Boolean (개념 졸업에 따른 자동 아카이빙/숨김 처리 여부)"
    }
    ```

---

## 5. 서비스 간 API 연동 규격

1.  **AI Engine -> Spring Boot (Proposed Webhook)**
    *   `POST /api/internal/content/proposed`
    *   Body: `{ "lessonId": 123, "lawReference": "...", "newContent": "...", "validationDetails": "...", "hallucinationScore": 0.0 }`
2.  **Spring Boot -> AI Engine (Generate Trigger)**
    *   `POST /generate-content`
    *   Body: `{ "law_content": "...", "metadata": { "lesson_id": 123 } }`
3.  **Client -> Back-end -> AI Engine (Context AI Chat API)**
    *   `POST /api/chat/ask`
    *   Body:
        ```json
        {
          "question": "사용자 질문 본문",
          "context": {
            "quizId": "퀴즈 식별자",
            "question": "스토리텔링 질문",
            "options": ["보기1", "보기2", "보기3", "보기4"],
            "selectedIndex": 2,
            "answerIndex": 3,
            "lawReference": "산업안전보건법 제38조"
          }
        }
        ```
4.  **Client -> Back-end -> AI Engine (Adaptive Quiz Clinic API)**
    *   `POST /api/chat/adaptive-quiz`
    *   **Description**: 사용자의 가장 취약한 법령 조항을 기준으로 중복되지 않는 현장 시나리오의 변형 4지선다 퀴즈를 실시간(On-the-fly) 생성 요청합니다.
    *   **Body**:
        ```json
        {
          "memberId": "사용자 ID",
          "weakLawReference": "산업안전보건법 제38조",
          "excludeQuizIds": ["quiz-uuid-1", "quiz-uuid-2"]
        }
        ```
    *   **Response**:
        ```json
        {
          "quizId": "임시 발급된 UUID",
          "lawReference": "산업안전보건법 제38조",
          "question": "새롭게 생성된 실무 스토리텔링 지문",
          "options": ["변형 보기1", "변형 보기2", "변형 보기3", "변형 보기4"],
          "answerIndex": 1,
          "hint": "새로운 시나리오 기반 힌트",
          "explanation": "해당 조항과 시나리오에 대조되는 정교한 법리 해설"
        }
        ```
5.  **Client -> Back-end (Incorrect Note Deletion & Archiving API)**
    *   `DELETE /api/incorrect-notes/{id}`
    *   **Description**: 사용자가 오답노트에서 특정 오답을 영구히 학습 완료(Mastery)하였거나 정리하고 싶을 때 호출하는 개별 삭제 API입니다.
    *   **Headers**: `Authorization: Bearer <JWT Token>`
    *   **Params**: `id` (오답 기록의 로컬 UUID 또는 서버 DB 매핑 PK)
    *   **Action**: 해당 오답 레코드를 서버 DB에서 제거(또는 Soft-Delete)하고, 관련된 법령 조항의 `member_weakness_index` 취약 지수를 차감 보정 갱신합니다.
    *   **Response**: `200 OK` (성공 시)
6.  **Client -> Back-end (Quiz Submit & Mastery Check API)**
    *   `POST /api/quizzes/submit`
    *   **Description**: 퀴즈 채점 결과를 제출하고, 특정 조항에 대해 연속 3회 정답 달성 시 `member_incorrect_note` 내 기존 오답 기록을 `is_archived = true`로 일괄 업데이트하여 자동 졸업을 처리합니다.
7.  **Client -> Back-end (Incorrect Note Sync API - Push)**
    *   `POST /api/sync/incorrect-notes`
    *   **Description**: 오프라인 상태에서 발생한 로컬 오답 노트 데이터(새로운 오답, 상태 변경된 오답)를 서버로 동기화합니다. UUID 충돌 시 덮어쓰기(On Conflict Update)를 수행합니다.
8.  **Client <- Back-end (Pull Archived Status API)**
    *   `GET /api/sync/incorrect-notes/archived-status`
    *   **Description**: 앱 진입 시 서버에서 지능형 자동 졸업(`is_archived=true`) 처리된 오답 UUID 목록을 조회하여 로컬 디바이스 상태를 갱신(Pull)합니다.

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

### 6.5 클라이언트 로컬 오답 디바이스 저장소 영속성 보장 및 ACID 백업 (High)
*   **이슈**: 퀴즈 오답 발생 시, 네트워크 통신 지연이나 비정상 앱 종료로 인해 틀린 문제의 학습 기록 및 대화가 유실될 위험이 존재하며, 서버 동기화 시 데이터 중복 누적이나 동시성 연산 충돌이 발생할 수 있습니다.
*   **작업 내용**:
    *   [ ] `edu-client` 내 로컬 DB(Hive/SQLite)의 쓰기 락 및 비동기 쓰기 트랜잭션의 ACID 특성을 엄격하게 제어하는 에러 복구용 예외 처리 래퍼 작성.
    *   [ ] 로컬 DB 스키마에 `isSynced` 플래그 필드를 탑재하여 **로컬 아웃박스 패턴(Local Outbox Pattern)**을 적용하고, 백그라운드 네트워크 상태 감지(Connectivity 감지)에 따른 배치 일괄 동기화(Batch Sync) 로직 구현.
    *   [ ] 서버 API 수신부에 로컬 UUID 기반의 **멱등성 Upsert (Insert on Conflict Update)** 처리(로컬의 변경 상태를 안전하게 반영) 및 취약 지수의 **서버 레벨 원자적 업데이트(Atomic Update: `score = score + 1`)** 통제 장치를 연동하여 데이터 중복 및 병합 유실을 원천 예방.

### 6.6 지능형 변형 문제 중복 방지 및 Redis 캐싱 고도화 (Medium)
*   **이슈**: 실시간 변형 퀴즈 `[U-6]` 호출 시, LLM 추론 지연 및 학습자당 수십 개의 이전 퀴즈 기록 대조로 인한 성능 오버헤드가 발생할 수 있습니다.
*   **작업 내용**:
    *   [ ] 사용자의 최근 퀴즈 수강 ID 리스트를 Redis Set 자료구조(`learner_quiz_set:{memberId}`)에 적재하고, 실시간 필터 쿼리를 메모리 레벨에서 초고속 처리하도록 설계.
    *   [ ] 동일 조항에 대한 변형 생성 템플릿의 다양성을 보장하기 위해 가상 도메인 카테고리(제조업, 건설업, 화학공장 등)를 유동적으로 믹싱하는 프롬프트 변동 파라미터(Randomized System Directive) 체계 구현.

---

## 7. 핫픽스 (Phase 2.5): 퀴즈 피드 파이프라인 완전 자동화 및 장애 해결

### Goal Description
앱에서 로그인 성공 후 [피드] 탭에 진입 시 "출제된 문제가 없습니다."라고 출력되는 문제를 근본적으로 해결하기 위한 파이프라인 수리 계획입니다. AI 엔진이 구조화된 퀴즈 데이터를 생성하도록 스키마를 고도화하고, 백엔드 서버에 퀴즈 은행 및 클라이언트 연동 API를 신설하여 클라이언트가 퀴즈 피드를 정상 수신하도록 조치합니다.

### User Review Required
> [!IMPORTANT]
> - AI 엔진의 프롬프트 및 응답 스키마가 변경되어 구조화된 JSON 데이터 형식을 반환하게 됩니다.
> - 백엔드의 DB 스키마에 `QuizBank` 관련 엔티티와 테이블이 추가되며, AI 엔진 결과 승인 시 퀴즈 데이터를 영속화하는 파이프라인이 추가됩니다.

### Proposed Changes

#### AI Engine
##### [MODIFY] [app/services/generator.py](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/ai-engine/app/services/generator.py)
- `CurriculumGeneration` Pydantic 스키마의 `quiz_proposed: str` 단일 필드를 제거하고, `quiz_question`, `quiz_options` (List[str]), `quiz_answer_index`, `quiz_hint`, `quiz_explanation` 필드로 구조화하여 분리.
- LLM System Prompt를 수정하여 반드시 구조화된 필드에 맞게 퀴즈를 출제하도록 프롬프트 엔지니어링 수행.

#### Spring Boot Back-end
##### [NEW] [QuizBank.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/quiz/QuizBank.java)
- 통합 문제 은행 엔티티 (id, lessonId, lawReference, question, options, answerIndex, hint, explanation) 생성.
##### [NEW] [QuizBankRepository.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/quiz/QuizBankRepository.java)
- JpaRepository를 상속받은 리포지토리 생성.
##### [NEW] [QuizController.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/quiz/controller/QuizController.java)
- 클라이언트용 `GET /api/v1/quizzes` 피드 API 엔드포인트 구현 (임시로 랜덤 조회 기능 탑재).
##### [MODIFY] [ApprovalService.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/approval/service/ApprovalService.java)
- AI 엔진 Webhook 응답 스키마(DTO) 업데이트.
- 관리자가 생성된 콘텐츠를 "승인(Approved)" 처리할 때, ApprovalRequest에 담긴 퀴즈 메타데이터를 파싱하여 `QuizBankRepository.save()`를 호출하는 로직 추가.

#### Flutter Front-end
##### [MODIFY] [quiz_bank_provider.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/quiz/providers/quiz_bank_provider.dart)
- 에러 발생 시 무음(Silently) 처리하여 빈 배열(`[]`)을 반환하는 대신, 에러 로그를 남기고 예외를 다시 던지거나 UI에 에러 상태가 표시되도록 에러 핸들링 로직 개편.

### Verification Plan

#### Automated Tests
- Postman 또는 Curl을 통해 AI 트리거 후 관리자 대기열에서 승인 요청 시, `quiz_bank` DB 테이블에 정상적으로 Row가 추가되는지 확인.
- `GET /api/v1/quizzes` API 호출 시 구조화된 JSON 데이터 배열이 반환되는지 확인.

#### Manual Verification
- 클라이언트 Flutter 앱 로그인 후 [피드] 탭 진입 시, 더 이상 "출제된 문제가 없습니다."가 뜨지 않고 AI가 생성한 객관식 문제가 Swipe 형태로 정상 노출되는지 육안 확인.

---

## 📝 추후 계획 (Future Memo)
- **오답노트 즉석 생성(On-the-fly) API 파이프라인 개발**:
  - 향후 새로운 대화 세션에서 작업할 내역입니다.
  - 현재 핫픽스는 사전에 생성된 퀴즈를 DB(`quiz_bank`)에서 가져와 피드에 뿌려주는 역할만 담당합니다.
  - 추후 오답노트 탭에서 사용자의 취약 조항(예: 자주 틀리는 법령)에 대해 "취약점 극복 훈련"을 실행할 때, AI가 즉석에서 새로운 시나리오의 변형 퀴즈를 생성하여 실시간으로 반환하는 `POST /api/chat/adaptive-quiz` API 및 AI 프롬프트 체인을 별도로 개발해야 합니다.
