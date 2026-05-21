# EverLaw Edu AI Engine: 최신 법령 DB 기반 교육 콘텐츠 자율 생산 및 검증 엔진

EverLaw Edu AI Engine은 국가 표준 법령 DB를 지식의 절대적 원천(Source of Truth)으로 삼아, 교육에 필요한 마크다운 강의안과 평가용 모의 퀴즈를 무(無)에서 유(유)로 동적 창작해내고, 이 생성된 콘텐츠가 법적 팩트와 수치에 부합하는지 교차 사실 검증을 수행하는 하이브리드 RAG 에이전트 시스템입니다.

본 프로젝트는 대규모 비즈니스 확장과 협업을 완벽히 수용하기 위해 설계된 **Ingestion-Serving 분리형 프로덕션 아키텍처(Ingestion-Serving Separated Architecture)**를 엄격하게 적용하여 구현되었습니다.

---

## 1. 개요

### 1.1 프로젝트 핵심 가치
*   **콜드 스타트 완벽 극복**: 기존 강의 교안을 보유하고 있지 않은 고객도 최신 법령 DB만 탑재하면 맞춤형 컴플라이언스 교육 자료를 즉시 오토-제너레이션할 수 있습니다.
*   **절대적 팩트 안전장치**: AI 자가 검증 감사 체인을 장착하여 원본 법령 수치(숫자, 기한)와 생성 교안 간의 불일치를 1대1로 대조하고, 미세한 왜곡 발생 시 즉시 빨간 불(🔴 Red Flag)로 반려 처리합니다.
*   **Ingestion-Serving 아키텍처 격리**: 데이터 수집/파싱 파이프라인(Ingestion)과 에이전트 서빙/웹 API/생산(Serving) 레이어가 물리적으로 분리되어, 모듈 간의 결합도가 매우 낮고 독립적인 배포 및 고도화가 가능합니다.
*   **원스톱 백그라운드 구동**: FastAPI `lifespan` 컨텍스트를 도입해, 단 하나의 API 서버 구동만으로 깃허브/RSS 상시 감시 스케줄러와 임베딩 자동 적재(신선도 유지)가 스레드로 병행 처리됩니다.

### 1.2 기술 스택 및 요구 사양
*   **AI Framework**: LangChain, LangGraph 기반 다중 노드 워크플로우
*   **LLM & Embedding**: Google Gemini 3.1 Flash-Lite (초저지연 구조화 추론) / Ollama `bge-m3` Embedding (로컬 인퍼런스)
*   **Database**: PostgreSQL 17 (pgvector), Redis (Seen 캐싱 및 비동기 작업 큐)
*   **Backend Server**: FastAPI (Lifespan Context Manager & APScheduler 연동)
*   **Environment**: Python 3.12+ (uv 의존성 패키지 관리 도구)

---

## 2. 시스템 아키텍처 및 데이터 흐름

### 2.1 디렉토리 구조 (Directory Structure)
본 AI 엔진의 구조는 역할과 관심사가 다음과 같이 명확히 나누어져 있습니다.

```text
ai-engine/
├── app/
│   ├── api/
│   │   └── v1/
│   │       └── endpoints.py     # FastAPI 라우팅 및 DTO 스키마
│   ├── core/
│   │   ├── config.py            # 전역 환경 변수, LLM/Embedding & Redis 리소스 초기화
│   │   └── database.py          # pgvector RAG DB 커넥션 및 SQL-level 멱등성 Upsert 로직
│   ├── ingestion/
│   │   ├── parser.py            # 가지조항 Regex 및 5단계 헤더 기반 시맨틱 청킹 정밀 파서
│   │   └── scheduler.py         # MOEL RSS 및 GitHub API 스캐너 (LawScanner)
│   └── services/
│       ├── generator.py         # RAG 기반 교안/퀴즈 자율 생성 노드 (Gemini 3.1)
│       ├── validator.py         # 0% 환각 팩트체크 교차 대조 감사 노드
│       └── graph_workflow.py    # LangGraph StateGraph 컴파일 및 추론 서비스 진입점
├── backup_old/                  # [임포트 충돌 방지] 이전 레거시 소스 백업 보관 폴더
├── scripts/
│   └── seed.py                  # 초기 대한민국 3대 법령 데이터 벌크 벡터 적재 시더
├── main.py                      # FastAPI 및 lifespan 스케줄러 웹 서버 진입점
├── scheduler_main.py            # 스케줄러 단독 기동용 엔트리 포인트
├── test_rag.py                  # 신규 프로덕션 아키텍처 기반 RAG E2E 종합 테스트 스키마
└── pyproject.toml
```

### 2.2 다중 에이전트 워크플로우 (LangGraph)
AI 엔진은 정교한 3단계 상태 그래프(StateGraph) 메커니즘에 따라 한 지점의 오차도 없이 자율 작동합니다.

```mermaid
graph TD
    A["사용자 요청: 교육 주제 입력"] --> B["1. retrieve 노드 (app/services/generator.py)"]
    B -->|"law_documents 테이블 의미론적 검색"| C["최신 법령 전문 팩트 추출"]
    C --> D["2. generate 노드 (app/services/generator.py)"]
    D -->|"Gemini 3.1 Flash-Lite 창작"| E["스토리텔링 교안 및 모의 퀴즈 무에서 유로 생산"]
    E --> F["3. validate 노드 (app/services/validator.py)"]
    F -->|"원본 법령 데이터와 1대1 수치 교차 대조"| G{"사실 검증 통과 여부?"}
    G -->|"🟢 PASS: 환각율 0.0%"| H["적합 상태 및 리포트 배출"]
    G -->|"🔴 FAIL: 수치/의도 불일치"| I["수동 검토 경고 Red Flag 점등 및 감사 소견서 첨부"]
```

### 2.3 RAG 데이터베이스 레이아웃
*   **`law_documents`**: 국가 법령 및 깃허브 커밋 개정안에서 수집한 최신 조문 전문이 임베딩되어 적재되는 RAG 지식 소스 테이블 (Ground Truth).
*   **`curriculum_documents`**: AI가 최신 법령을 마중물로 삼아 자율 생산해낸 강의 마크다운 본문 및 퀴즈가 누적되는 테이블.

---

## 3. 핵심 기능 명세

### 3.1 실시간 스캐너 및 스마트 해시 CDC 업서트
*   [app/ingestion/scheduler.py](./app/ingestion/scheduler.py)는 고용노동부 RSS 및 지정 GitHub 저장소의 커밋 변경을 감지합니다.
*   **실시간 전체 청킹 파이프라인**: 깃허브 변경 감지 시, 불완전하고 취약한 패치 기반의 조항 번호 추출 방식을 탈피하고 **파일 전문(Whole File)을 실시간 다운로드**하여 공통 파이프라인인 `split_law_markdown_to_documents`로 유도합니다.
*   [app/ingestion/parser.py](./app/ingestion/parser.py)의 정밀 파서가 `##### 제N조 (제목)` 마크다운 규칙과 **볼드체 항 번호 기호(①~㊿)**, 가지조항(`제4조의2` 등)을 고성능 정규표현식으로 정밀 가공하여 **조(Article) 단위 완결 청크**를 배출합니다.
*   **스마트 SHA-256 해시 CDC (Change Data Capture)**: [app/core/database.py](./app/core/database.py)에서는 각 청크의 본문 내용에 대한 SHA-256 해시 값을 산출하여, 적재 시점에 데이터베이스 내부의 `cmetadata` 필드 내 `chunk_hash` 정보와 대조합니다. 해시가 완벽히 동일하다면 **해당 청크의 임베딩 생성 API 호출과 트랜잭션을 통째로 건너뛰어(SKIP)** 성능과 인프라 비용 효율성을 극대화합니다.
*   **물리 SQL-level 멱등성 갱신**: 해시 값 변경이 확인되면, 불변의 고유 비즈니스 키(`law_{law_name}_{article}`)를 기준으로 기존 구버전 레코드를 데이터베이스에서 **물리적으로 완전히 선삭제(DELETE)**한 후 깨끗하게 `INSERT`함으로써, 중복 누적 및 유령 RAG 데이터를 0.0%로 완벽 차단합니다.

### 3.2 법령 근반 자율 콘텐츠 생산 엔진
*   [app/services/generator.py](./app/services/generator.py)는 pgvector에서 추출한 초신선 법률 지식을 Context로 주입받아, 딱딱한 조문 텍스트를 생생한 현장 가상 시나리오와 안전 행동 수칙으로 각색 가공하여 고품질의 마크다운 강의 교안을 동적 배출합니다.
*   학습자의 학습도를 평가할 수 있는 객관식 4지선다 모의 평가 퀴즈와 정답, 친절한 해설을 JSON 구조체 형식(`CurriculumGeneration` Pydantic 모델)으로 생산해 냅니다.

### 3.3 정밀 AI 자가 감사 시스템
*   [app/services/validator.py](./app/services/validator.py)는 생산된 마크다운 강의 본문과 퀴즈에 포함된 모든 규제 수치(예: 높이 2m, 벌금 5천만원 등)를 RAG 법령 팩트와 대조 감사하여 왜곡률을 백분율로 계산한 환각 위험 지수 (Hallucination Score)를 출력합니다.
*   환각 위험도가 일정 수치를 초과하면 관리자 대시보드에 긴급 수동 검토 권고 경고등을 켜고 감사 소견서를 마크다운 최하단에 강제 바인딩합니다.

---

## 4. 로컬 환경 구축 및 실행 방법

### 4.1 가상 환경 초기화 및 패키지 설치
본 엔진은 **Python uv**를 표준 패키지 관리자로 사용합니다.

```bash
# uv 도구를 사용한 의존성 동기화 및 가상환경 세팅
uv sync
```

### 4.2 환경 변수 구성
`ai-engine/.env` 파일을 작성하고 로컬 Mac Mini의 인프라 스펙을 매핑합니다.

```env
GOOGLE_API_KEY="your_google_gemini_api_key"
OLLAMA_BASE_URL="http://localhost:11434"
POSTGRES_URL="postgresql+psycopg2://user:password@localhost:5432/everlaw_db"
REDIS_URL="redis://localhost:6379/0"
LLM_MODEL="gemini-3.1-flash-lite"
EMBEDDING_MODEL="bge-m3"
GITHUB_REPO="legalize-kr/legalize-kr"
GITHUB_TOKEN="your_github_personal_access_token_optional"
MOEL_RSS_URL="https://www.moel.go.kr/news/notice/noticeList.do"
```
 
### 4.2.1 [선택] Redis 캐시 데이터 초기화 (스캐너 강제 재수집용)
스캐너 개발 및 RAG 동기화 테스트 시, GitHub 실시간 감시 데몬이 이미 수집을 완료한 커밋일지라도 "신규 개정 감지"로 강제 리셋하여 Smart CDC(변동분 멱등 적재 및 무변경 스킵) 흐름을 재테스트하려면 로컬 Docker Redis 캐시를 다음 명령어로 즉시 초기화할 수 있습니다:

```cmd
# Docker 컨테이너 상의 Redis 캐시 전체 소거 (강제 재감지용)
docker exec -it everlaw_redis redis-cli flushall
```

### 4.3 초기 대한민국 3대 법령 데이터 벌크 시딩 (Seeding)
처음 프로젝트 구동 시, 원격 깃허브 저장소로부터 최신 산업안전보건법 3대 조문(법률, 시행령, 시행규칙) 전문을 마크다운 계층형 공통 파서인 `split_law_markdown_to_documents`로 정교하게 분석 가공하여 벡터 데이터베이스에 시딩하는 스크립트를 기동합니다.

*   **안전한 사전 클렌징**: 시딩 재실행 시 기존 비즈니스 고유 키 레코드가 완전 리셋되도록 데이터베이스 사전 클렌징 쿼리를 수행해 잔여 유령 쓰레기 적재분을 완전히 소거합니다.
*   **비조항 청크 충돌 해결**: 조 번호가 존재하지 않는 부칙, 목적 등의 특수 청크에 대해 `seed_{law_name}_{law_type}_{chunk_idx}` 형태의 결정론적 fallback `law_id`를 임포트 주입하여, 추후 실시간 스캐너 감지 및 병합 시 식별자 충돌과 중복 누적을 원천 방어합니다.

```cmd
# Windows CMD 및 모든 쉘 환경 벌크 시딩 실행
uv run python -X utf8 scripts/seed.py
```


### 4.4 서버 가동 및 수집 데몬 활성화
FastAPI 서버 기동 단 한 번의 명령으로 내부 백그라운드 스케줄러(APScheduler) 스레드까지 원클릭 통합 가동됩니다. 

Windows CMD를 비롯한 모든 쉘 환경(CMD, PowerShell, macOS Bash/Zsh)에서 별도의 환경 변수 주입 없이 **100% 동일하게 정상 기동되는 현대적인 파이썬 표준 UTF-8 플래그 기동법**을 사용합니다.

#### 1) 표준 서버 가동 명령 (추천)
```cmd
# 윈도우 인코딩 크래시를 원천 방어하는 글로벌 UTF-8 모드 서버 기동
# 백그라운드 스케줄러(수집 주기), 데이터베이스 커넥션, Lifespan 이벤트를 정밀 검증할 때:
# 핫 리로드의 부작용을 예방하기 위해 1번 표준 명령어로 직접 껐다 켜면서 테스트하시는 것이 안전합니다.
uv run python -X utf8 main.py
```

#### 2) 개발자용 Uvicorn 핫 리로드(Hot-Reload) 기동
코드 수정 시 자동으로 서버를 재기동해 주는 개발 친화적 기동 방식입니다.
```cmd
# uvicorn 실행 시에도 동일하게 -X utf8 플래그 주입 기동
uv run python -X utf8 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
> [!NOTE]
> 서버가 성공적으로 구동되면 백그라운드 스케줄러 스레드가 1시간 주기로 RSS와 깃허브 API 감시 사이클을 자동 기동하여 실시간으로 벡터 DB의 법령 신선도를 최신 상태로 유지 보존합니다.

### 4.5 RAG 파이프라인 E2E 테스트 실행
가상환경 파이썬 바인딩 상에서 E2E RAG 엔진 테스트 및 AI 자가 검증 감사 작동 실증을 테스트합니다. 

```cmd
# Windows CMD 및 모든 쉘 환경 표준 테스트 기동
uv run python -X utf8 test_rag.py
```
