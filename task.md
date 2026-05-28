# 문제 출제소 일괄 처리 및 조당 5제 출제 픽스 작업

- `[x]` Flutter: `approval_provider.dart`에 `selectedLawsProvider` 상태 추가
- `[x]` Flutter: `quiz_generation_factory_screen.dart` 다중 선택 UI (체크박스, 전체 선택) 및 FAB 구현
- `[x]` 에러 로그 확인 (Spring Boot 500 예외 방어)
- `[x]` edu-client 폴링 로직 동시성 이슈 분석 및 해결 (조항별 순차 처리, `isGenerated` 오동작 수정, `ApprovalQueueScreen` UI 수정)
- `[x]` 일괄 출제(조당 5제) 생성 시 다양한 문제가 출제될 수 있도록 Diversity 보장 로직 분석 (`quiz_diversity_analysis.md`)
- `[x]` 단일 '다시 출제하기' 버튼의 폴링 오동작(`isGenerated` 함정) 수정

### Multi-hop RAG 기반 참조 별표 자동 검색
- `[x]` AI 엔진 AgentState 및 API 파라미터 구조에 `law_id` 추가 (`endpoints.py`, `graph_workflow.py`, `generator.py`)
- `[x]` `generator.py`의 `retrieve` 노드에 정규식 기반 참조 별표 탐지 및 2차 벡터 검색 로직 추가
- `[x]` `adaptive_generator.py`에도 동일한 2차 검색 로직 이식
- `[x]` 테스트 및 검증
- `[x]` [완료] HWP/PDF 별표 원본 데이터 누락으로 인한 환각/메타질문 방지를 위해, 프롬프트 강제 규칙(원칙/목적 위주 출제) 적용 완료
- `[x]` Spring Boot: `ApprovalService.java`에서 `triggerContentGeneration` 5회 반복 및 Adaptive 컨텍스트 연동 로직 수정
- `[x]` AI Engine: `generator.py`, `graph_workflow.py`, `endpoints.py`에 `previous_questions` 연동을 통한 절대 중복 방지 프롬프트 추가
- `[x]` 작업 내용 검증 및 확인 완료 (Timeout 원인 분석 및 해결)
