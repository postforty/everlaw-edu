# 문제 출제소 일괄 처리 및 조당 5제 출제 픽스 작업

- `[x]` Flutter: `approval_provider.dart`에 `selectedLawsProvider` 상태 추가
- `[x]` Flutter: `quiz_generation_factory_screen.dart` 다중 선택 UI (체크박스, 전체 선택) 및 FAB 구현
- `[x]` Flutter: `_generateSelectedQuizzes` 비동기 순차 호출 완료 확인 폴링 로직 적용 (타임아웃 동시성 버그 수정)
- `[x]` Spring Boot: `ApprovalService.java`에서 `triggerContentGeneration` 5회 반복 및 Adaptive 컨텍스트 연동 로직 수정
- `[x]` AI Engine: `generator.py`, `graph_workflow.py`, `endpoints.py`에 `previous_questions` 연동을 통한 절대 중복 방지 프롬프트 추가
- `[x]` 작업 내용 검증 및 확인 완료 (Timeout 원인 분석 및 해결)
