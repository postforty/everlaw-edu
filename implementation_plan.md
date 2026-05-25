# EverLaw Edu 마스터 구현 계획서 (Master Implementation Plan)

## 1. 프로젝트 개요 및 현재 상태
EverLaw Edu는 국가 표준 법령 DB를 기반으로 실무용 교육 퀴즈를 무(無)에서 유(有)로 대량 자율 생산하는 시스템입니다.
현재 AI 엔진(법령 RAG 및 퀴즈 자동 생성), Spring Boot 백엔드(문제 은행 및 결재 시스템), Flutter 프론트엔드(관리자 및 학습자 뷰)의 코어 파이프라인(Phase 1~2) 구축이 완전히 완료되었습니다.

### 완료된 주요 파이프라인 (요약)
- **AI 엔진**: 법령 전문 SQL-level Upsert 및 해시 기반 중복 방지 로직, 4지선다 퀴즈 전용 생성 체인, 환각 자가 검증(Hallucination Score) 노드 구현.
- **백엔드**: JPA/PostgreSQL 기반 퀴즈 뱅크(`quiz_bank`) 및 결재 대기열(`approval_request`) 구축, AI Webhook 연동.
- **프론트엔드**: Flutter 이론 강좌 탭 제거 후 퀴즈 중심 UX 개편, 근거-퀴즈 대조 승인 UI, 실시간 퀴즈 피드 렌더링.

---

## 2. 향후 구현 계획 (Future Phases)
현재 가장 우선순위가 높은 킬러 기능인 **"학습자 맞춤형 오답 관리 및 지능형 즉석 변형 퀴즈 출제"** 코어 루프 완성에 집중합니다.

### Phase 3: 학습자 맞춤형 오답 관리 및 클리닉 (Next Target)
- `[ ]` **[U-7] 오답노트 개별 삭제 및 취약 지수 연동 API**
  - 클라이언트 오답 로컬 DB와 서버(`member_incorrect_note`) 간 동기화 (아웃박스 패턴 적용).
  - 오답 삭제(극복) 시 `member_weakness_index` 취약 지수 차감 보정 비즈니스 로직.
- `[x]` **[U-8] 연속 정답 추적 및 지능형 자동 졸업 시스템**
  - 퀴즈 채점 제출 API(`POST /api/quizzes/submit`) 호출 시, **3회 연속 정답 여부 판정**.
  - 조건 충족 시 해당 조항 연계 구버전 오답 데이터를 `is_archived = true`로 일괄 아카이빙하고 취약 지수 즉시 0점 리셋.
  - Flutter 앱 내 "개념 정복(Mastery) 성공 및 자동 졸업" 축하 애니메이션(Lottie) 연출.
- `[x]` **🔥 [U-6] 지능형 변형 퀴즈 즉석 출제 (Adaptive AI Quiz Clinic)**
  - 가장 취약한 법령 조항에 대해, 이전에 풀었던 지문과 겹치지 않는 새로운 시나리오 퀴즈를 **즉석(On-the-fly) 생성**하는 `POST /api/chat/adaptive-quiz` 파이프라인 및 LangGraph 프롬프트 체인 구축.
  - 동일 조항에 대한 변형 생성 다양성을 위해 제조, 건설, 화공 등 가상 도메인 카테고리를 믹싱하는 프롬프트 변동 정책 적용.

### Phase 4: 기술 부채 개선 및 배포 안정화 (Backlog)
- `[x]` **AI DB 커넥션 최적화**: SQLAlchemy 커넥션 풀 소켓 누수 차단 및 싱글톤화.
- `[x]` **비동기 마이그레이션**: LangGraph 워크플로우를 비동기(Async) 체계로 마이그레이션하여 FastAPI 추론 지연 및 블로킹 I/O 해결.
- `[x]` **GitHub API 예외 처리**: 깃허브 Rate Limit 예외 처리 및 토큰 주입 정밀화.
- `[ ]` **통합 E2E 테스트**: 오프라인 디바이스 환경에서의 데이터 정합성 검증 등.

---

## 3. 핵심 데이터 스키마 & API 규격 (Reference)

### 핵심 데이터베이스 (PostgreSQL)
*   **`quiz_bank`**: 생성된 4지선다 퀴즈 정보 보관.
*   **`member_weakness_index`**: 사용자별 법령 조항별 누적 오답 횟수 및 취약 지수(`weakness_score`).
*   **`member_incorrect_note`**: 사용자의 오답 기록 서버 통합 레코드 (로컬 오프라인 데이터의 멱등성 동기화용).
*   **`client_incorrect_note`**: 클라이언트 로컬 오답 노트 (JSON 직렬화 구조로 오프라인 복습 지원).

### 주요 API 연동 규격
*   `POST /api/chat/ask`: 해설 패널 인라인 AI 챗봇 컨텍스트 연동 (오답 이유와 힌트 피드백).
*   `POST /api/chat/adaptive-quiz`: 취약점 극복용 변형 퀴즈 온더플라이(On-the-fly) 생성 트리거.
*   `DELETE /api/incorrect-notes/{id}`: 로컬 오답 기록 삭제 시 서버 동기화 및 취약 지수 차감.
*   `POST /api/sync/incorrect-notes`: 네트워크 연결 시 로컬 오답 기록을 서버에 일괄 푸시(Push) 동기화.
*   `GET /api/sync/incorrect-notes/archived-status`: 자동 졸업(`is_archived`) 상태를 서버에서 풀(Pull)해와 로컬 오답노트에 반영.

---

## Phase 4: 관리자 문제 출제소(Admin Quiz Generation UI) 구축

현재 CLI(`build_mode_a.py`)를 통해 트리거되던 문제 출제 프로세스를 앱 내부(Flutter) 관리자 UI로 내재화합니다.

### 1. 목표
* AI 엔진(PGVector)에 적재된 법령(Source Law) 리스트를 조회.
* Flutter 관리자 화면에서 원하는 조항(Article)을 선택하여 즉시 문제 생성 요청.

### 2. 백엔드 및 AI 엔진 변경 사항
#### [NEW] FastAPI Endpoint (`/api/v1/source-laws`)
* **목적**: `langchain_pg_embedding` 테이블의 메타데이터(`law_name`, `article`)와 원본 `document`를 고유 목록으로 조회 반환.
* **파일**: `ai-engine/app/api/v1/endpoints.py` 수정.

#### [NEW] Spring Boot Proxy API (`/api/v1/approvals/source-laws`)
* **목적**: FastAPI가 제공하는 법령 원천 데이터 목록을 Flutter 앱에 프록시 제공.
* **파일**: `ApprovalController.java`, `ApprovalService.java` 수정.

### 3. 클라이언트 (Flutter) 변경 사항
#### [NEW] `SourceLaw` 모델 및 Provider
* API 응답(`law_name`, `article`, `content`)을 매핑할 모델 및 Provider 생성.
* 기존 `ApprovalProvider`에 `triggerGeneration(lawId, lawContent)` 메서드 추가 (기존 `/generate` API 연동).

#### [NEW] `QuizGenerationFactoryScreen`
* 관리자가 원본 법령 데이터를 조회하고 퀴즈 생성을 명령할 수 있는 "문제 출제소" 화면.
* 목록에서 [문제 출제] 버튼 클릭 시 로딩 애니메이션과 함께 API를 호출하고, 완료 시 [승인 대기열] 화면으로 라우팅.

#### [MODIFY] `ApprovalQueueScreen` 
* 앱바에 "문제 출제소"로 이동할 수 있는 플로팅 액션 버튼 또는 앱바 액션 추가.

## User Review Required
> [!IMPORTANT]
> - 현재 백엔드 생성 트리거(`GenerateTriggerRequest`)에는 `curriculumId` 필드가 필수값으로 포함되어 있는데, 향후 커리큘럼 기반에서 법령 조항 기반으로 완전 전환 시 이 필드를 더미(Dummy) 처리할지 백엔드 엔티티 수정을 동반할지 결정이 필요합니다. (본 계획에서는 `curriculumId = 1` 더미로 우선 전송하여 구조를 단순화합니다.)
> - 문제 생성 완료 시 자동으로 Approval Queue(콘텐츠 승인 대기열) 화면으로 이동하여 관리자가 바로 승인할 수 있도록 UX를 구성하겠습니다. 동의하시나요?

---

## Phase 4.1: 문제 출제소 UX 보완 (정렬, 내용 분리, 상태 표시)

관리자가 문제 출제소 화면을 더욱 직관적으로 사용할 수 있도록 정렬 기준과 기출제 상태를 추가합니다.

### 1. 목표
* 조항(Article)을 숫자 기준으로 오름차순 자연 정렬(Natural Sort)하여 표시.
* 무작위 청크(Chunk) 내용이 제목과 불일치해 보이는 현상을 제거하기 위해 내용 표시 생략.
* 이미 출제되었거나 승인 대기열에 있는 조항인지 판별하여 버튼 상태 분기(비활성화).

### 2. 백엔드 및 AI 엔진 변경 사항
#### [MODIFY] FastAPI Endpoint (`/api/v1/source-laws`)
* SQL 쿼리에서 `document` 청크 반환을 제거하여 혼동을 방지.
* Python 정규식(`re.search(r'\d+', article)`)을 활용하여 '제1조', '제2조', '제10조' 등의 조항을 숫자 크기 순으로 완벽하게 정렬하여 반환.

#### [MODIFY] Spring Boot API & Service (`ApprovalService`, `SourceLawResponse`)
* `SourceLawResponse` DTO에 `boolean isGenerated` 필드 추가.
* `QuizBankRepository` 및 `ApprovalRequestRepository`에 `@Query`를 추가하여 이미 적재된 `lawReference` 목록을 `Set<String>` 형태로 추출.
* FastAPI 응답을 프록시할 때, 추출한 `Set`을 대조하여 기출제 여부(`isGenerated = true`)를 판별해 반환.

### 3. 클라이언트 (Flutter) 변경 사항
#### [MODIFY] `SourceLaw` 모델 및 `QuizGenerationFactoryScreen`
* 모델에 `isGenerated` 속성 추가 및 파싱 적용.
* 무작위 텍스트 청크를 보여주던 UI를 걷어내고, "조항 전문 기반 AI 퀴즈 생성" 이라는 깔끔한 안내 문구로 대체.
* `isGenerated`가 `true`일 경우, [AI 퀴즈 출제하기] 버튼을 비활성화(Disabled) 처리하고 라벨을 [기출제 완료] 또는 [승인 대기 중]으로 변경하여 중복 출제 원천 차단.

## User Review Required
> [!IMPORTANT]
> - 정렬 방식은 `law_name`(예: 산업안전보건법) 가나다순 정렬 후, `article`(제X조) 내부 숫자를 파싱하여 오름차순으로 정렬할 예정입니다.
> - 이미 문제 은행에 들어갔거나(승인됨) 승인 대기열에 있는(PENDING) 항목은 모두 '기출제'로 묶어 중복 생성을 막겠습니다. 동의하시나요?
