# 📝 산업안전보건법 킬러 콘텐츠 및 마스터 커리큘럼 핫스왑 구현 TODO 리스트

- [x] **1단계: 챗봇 피처 신설 (`features/chatbot`)**
  - [x] `lib/features/chatbot/models/chat_message.dart` 모델 정의
  - [x] `lib/features/chatbot/providers/chatbot_provider.dart` 타이핑 딜레이 모의 AI 스트리밍 로직 개발
  - [x] `lib/features/chatbot/views/inline_chatbot_sheet.dart` 바텀 시트 및 빠른 질문 칩 인터랙티브 UI 개발

- [x] **2단계: 메타인지 비즈니스 로직 확장 (`lesson_provider.dart`)**
  - [x] `submitAnswer` 함수에 `confidenceLevel` 매개변수 추가 및 API/로컬 페이로드 전달
  - [x] 채점 결과와 확신도를 교차 매핑하여 4개 등급의 `metaCognitionStatus` 진단 Fallback 분석 모델 구축

- [x] **3단계: 가독성 및 메타인지 퀴즈 UI 튜닝 (`markdown_quiz_renderer.dart`)**
  - [x] 보기 선택 시 활성화되는 확신도 설문 폼(`확실히 앎` 🟢 / `헷갈림` 🟡 / `잘 모름` 🔴) 설계 및 애니메이션 효과
  - [x] 메타인지 진단 상태(`metaCognitionStatus`)에 대응하는 정교한 시각 피드백 카드 및 메타인지 요약 리포트 카드 설계

- [x] **4단계: 피처 연동 및 메인 화면 다듬기**
  - [x] `lesson_detail_screen.dart`에서 확신도 포함 제출 바인딩 및 우측 상단 챗봇 연결 플로팅 버튼 탑재
  - [x] `lesson_list_screen.dart` 상단에 최신 산업안전보건법 개정 큐레이션 추천 문안 리디자인

- [x] **5단계: 종합 검증 및 마무리**
  - [x] 메타인지 퀴즈 4가지 시나리오 정상 동작 검증 (flutter analyze 검증 통과)
  - [x] 챗봇 실시간 스트리밍 대답 및 리치 텍스트 렌더링 검사 (문법적 연동 검증 완료)

- [x] **6단계: [AI Engine] 마스터 챕터 초기 시딩 로직 개발 (`scripts/seed.py`)**
  - [x] 4가지 핵심 마스터 챕터 교안 및 초기 퀴즈 데이터를 `curriculum_documents` RAG 스토어에 기본 벌크 적재하는 로직 추가
  - [x] 기존 단순 조문 데이터 위주의 시딩 구조에 마스터 챕터 전용 테이블/필드 또는 구분 로직 장착

- [x] **7단계: [AI Engine] 핫스왑 매칭 & 리라이팅 구현 (`app/services/generator.py`)**
  - [x] 개정 법령 발생 시 RAG 검색(Cosine Similarity)으로 연관 마스터 챕터 타겟 매칭 및 기존 본문 로드
  - [x] Gemini 3.1 Flash-Lite가 기존 강의 본문 팩트를 차분 갱신하여 핫스왑 업데이트 및 신규 퀴즈를 JSON으로 생성하는 프롬프트 및 파서 구현

- [x] **8단계: [Client] Mock 데이터 마스터 구조화 (`lesson_provider.dart`)**
  - [x] `_mockLessons` 데이터를 단편 강좌가 아닌 4대 마스터 챕터 트랙으로 전면 재구조화
  - [x] 각 마스터 강좌 객체에 `isRecentlyRevised` (개정 여부), `revisionNumber` (리비전 차수) 메타 필드 추가

- [x] **9단계: [Client] 최신 개정 뱃지 및 메타인지 리마인더 UI 탑재 (`lesson_list_screen.dart`, `lesson_detail_screen.dart`)**
  - [x] 핫스왑된 챕터 카드 옆에 박동하는 `⚖️ 2026 최신 개정` 모던 그라데이션 뱃지 UI 추가
  - [x] 퀴즈가 갱신되었을 때 `lesson_detail_screen` 상단에 "법령 개정으로 퀴즈 갱신" 메타인지 리마인드 팁 카드 노출

- [x] **10단계: [Verification] 종합 검증 및 마무리**
  - [x] `test_rag.py` E2E 핫스왑 테스트 실행 및 검증 (성공 확인)
  - [x] 브라우저에서 핫스왑 뱃지와 리포트 카드 UI 최종 검증 완료
