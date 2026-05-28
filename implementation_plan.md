# 문제 출제소 일괄 처리 및 조당 5제 출제 최종 구현 계획

## Goal
여러 원본 법령을 다중 선택하여 한 번에 일괄 출제하는 기능을 추가합니다.
선택된 조항 하나당 무조건 5개의 변형 문제를 중복 없이 한 번에 생성(조당 5제 픽스)하도록 구조를 개편합니다.
LLM API 쿼터 초과 방지를 위한 쓰로틀링 방안과 사용자 경험(UX) 결정을 반영합니다.

## User Review Required
> [!NOTE]
> 1. **비동기 UI 동작**: 관리자가 일괄 출제를 누르면 카드의 버튼이 '출제 중'으로만 변경되며 화면 블로킹 없이 다른 업무를 볼 수 있습니다. 작업이 끝나면 스낵바 알림이 뜹니다.
> 2. **부분 성공 허용**: AI가 5세트를 생성하는 도중 환각(Hallucination)이 감지되어 일부가 반려되더라도, 나머지 정상 생성된 문제들은 폐기하지 않고 즉시 승인 대기열(Approval Queue)로 이관됩니다.
> 이 내용이 모두 반영되었습니다. 계획을 최종 승인(Approve)해 주시면 바로 코딩을 시작합니다!

## Proposed Changes

### 1. Flutter 클라이언트 (edu-client)

#### [MODIFY] `lib/features/approval/providers/approval_provider.dart`
- 다중 선택된 법령의 ID를 추적하기 위해 새로운 로컬 상태 프로바이더 `selectedLawsProvider` 추가.
  ```dart
  final selectedLawsProvider = StateProvider<Set<String>>((ref) => <String>{});
  ```

#### [MODIFY] `lib/features/approval/views/quiz_generation_factory_screen.dart`
- **AppBar 영역**: 전체 선택 / 선택 해제(Select All / Deselect All) 버튼 추가.
- **리스트 아이템(Card) 영역**: 
  - 각 법령 카드에 체크박스(Checkbox) 추가. 출제가 완료되었거나 생성 중인 항목은 체크박스를 비활성화합니다.
- **일괄 출제 액션**: 
  - 화면 하단에 **FloatingActionButton.extended** 노출. ("선택된 N개 조항 일괄 출제하기")
- **일괄 출제 비동기 로직 (`_generateSelectedQuizzes`)**:
  - 선택된 법령 ID 리스트를 `generatingLawsProvider`에 일괄 등록.
  - 병렬(`Future.wait`) 호출을 금지하고, `for`문을 통한 직렬 순차 호출을 적용.
  - **API 쓰로틀링 방어**: 조항 트리거 호출 사이에 강제 지연(`Future.delayed(Duration(seconds: 15))`) 부여.
  - 관리자가 다른 탭으로 이동하더라도 백그라운드에서 폴링이 정상적으로 동작하도록 로직 보완 및 폴링 횟수 연장. 완료 시 스낵바 송출.

### 2. Spring Boot 백엔드 & AI Engine (edu-server / ai-engine)

#### [MODIFY] `ApprovalService.java` 또는 AI Engine 내부 로직
- **5제 픽스 및 부분 성공 로직**: 단일 조항에 대한 출제 요청 시, 내부적으로 생성 파이프라인을 5회 반복 실행.
- **LLM 쓰로틀링 방어**: 5번의 반복 사이에 LLM API Limit(15 RPM)을 넘지 않도록 `asyncio.sleep(4)` 등을 삽입.
- 생성 중 자가 검증(Validator)을 실패하는 문제가 나오더라도 해당 건만 Drop하고, 검증을 통과한 나머지 정상 문제들은 즉시 승인 대기열(Approval Queue)에 적재.

## Verification Plan

### Manual Verification
1. 앱 실행 후 출제소 화면에서 '전체 선택' 버튼을 누름.
2. 하단의 플로팅 버튼을 클릭.
3. 로딩 상태에서 다른 탭으로 이동했다가 잠시 뒤 다시 돌아와도 에러 없이 폴링이 계속 유지되는지 체크.
4. Python 서버 로그에서 5세트를 생성할 때마다 딜레이가 적용되며 429 에러가 발생하지 않는지 확인.
5. 출제가 끝난 후 승인 대기열에 이동하여, 환각으로 일부가 Drop된 케이스를 포함해 성공한 문제들이 정상적으로 렌더링되는지 확인.
