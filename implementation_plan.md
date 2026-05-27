# 📝 [U-7] 오답노트 개별 삭제 및 취약 지수 연동 기능 구현 계획 (TDD 적용 개정판)

본 계획서는 현재 미구현된 `오답 삭제 시 취약 지수 차감 보정 비즈니스 로직`과 클라이언트의 `아웃박스 패턴 기반 로컬 DB 동기화`를 **TDD(테스트 주도 개발) 방식으로 안전하게 구현**하기 위한 상세 방안입니다. 
시니어 엔지니어 코드 리뷰 결과 지적된 12가지 갭(이중 차감 방어, 네트워크 상태 감지 누락, 스키마 버전 관리, UI 애니메이션 누락 등)이 모두 해결 및 반영되어 있습니다.

---

## 🚀 TDD (Test-Driven Development) 프로세스 원칙

본 피처의 모든 핵심 로직은 **테스트 코드를 먼저 작성하고 본 코드를 작성하는 TDD 프로세스를 강제**합니다.

1. **Red (테스트 작성)**: 비즈니스 요구사항 및 예외 상황(이중 삭제, 오프라인 삭제 등)을 검증하는 테스트 케이스를 먼저 구현하여 실패하는 상태를 만듭니다.
2. **Green (코드 구현)**: 테스트를 통과시킬 수 있는 가장 간결하고 방어적인 본 코드를 구현합니다.
3. **Refactor (리팩터링)**: 중복을 제거하고 가독성을 높이며 성능을 최적화합니다.

---

## 📢 User Review Required

> [!IMPORTANT]
> - **TDD 개발 적용**: 백엔드의 서비스 레이어 테스트 및 프론트엔드의 Riverpod StateNotifier/데이터베이스 테스트가 본 기능 구현보다 먼저 개발 및 통과되어야 합니다.
> - **차감 점수 밸런스 통일**: 오답노트 수동 삭제 시 차감 점수는 기존 정답 학습 시의 혜택과 동일하게 **`-5.0점`**으로 통일합니다. (이전 계획의 `-10점`에서 게임 밸런스 통일을 위해 하향 조정)
> - **Windows & Linux 데스크톱 FFI 지원**: `sqflite` 구동을 위해 데스크톱 환경을 감지하여 초기화하는 코드를 구현합니다.
> - **네트워크 복구 동기화**: `connectivity_plus` 패키지를 신규 도입하여 온라인 복구 시 즉각 백그라운드 동기화를 트리거합니다.

---

## ❓ Open Questions

> [!WARNING]
> - **통계 이력 보존 정책**: 오답을 삭제하더라도 누적 학습 통계 지표인 `incorrectCount`(누적 오답 횟수)는 보존 목적 상 차감하지 않고 그대로 유지합니다. `weaknessScore`(취약 지수)만 차감 처리합니다. 이 정책에 동의하시나요?

---

## 🛠 Proposed Changes

### 1. 백엔드 (Spring Boot)

백엔드는 TDD 방식을 적용하여 서비스 테스트 코드를 선작성한 후 비즈니스 방어 로직을 순차 구현합니다.

#### [NEW] [ProgressServiceTest.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/test/java/com/everlaw/edu/domain/progress/ProgressServiceTest.java)
- **TDD 선작성 케이스**:
  1. **정상 삭제 및 취약 지수 차감 검증**: 오답 삭제 시 `weaknessScore`가 `-5.0` 차감되는지 확인 (단, `incorrectCount`는 그대로 유지되는지 확인).
  2. **이중 차감 방지 검증**: 동일 오답에 대해 연속 삭제 요청이 올 때(아웃박스 중복 전송 시나리오), 두 번째 요청은 에러 없이 성공하지만 취약 지수는 추가 차감되지 않는지 검증.
  3. **졸업(isArchived=true) 상태 방어 검증**: 이미 3회 연속 정답으로 인해 자동 졸업되어 `isArchived` 상태가 된 오답을 수동 삭제할 때, 중복 차감이 일어나지 않고 안전하게 무시되는지 검증.

#### [MODIFY] [MemberWeaknessIndex.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/progress/MemberWeaknessIndex.java)
- 수동 삭제 시 차감 보정을 위한 `decrementForDeletion()` 메서드를 추가합니다.
- **차감 점수 상수화**: 차감 점수 `-5.0`은 추후 게이미피케이션 밸런스 A/B 테스트를 위해 상수로 분리하여 관리합니다.
- **방어 로직 (음수 방지)**: `this.weaknessScore = Math.max(0.0, this.weaknessScore - 5.0);` 로 최하점을 0점으로 안전하게 격리합니다.
- **통계 유지 정책**: 통계 이력 보존 목적 상 `consecutiveCorrects` 및 `incorrectCount`는 명시적으로 차감하지 않고 그대로 유지합니다.

#### [MODIFY] [ProgressService.java](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-server/src/main/java/com/everlaw/edu/domain/progress/ProgressService.java)
- **정밀한 이중 차감 방어 및 아카이브 분기 로직 구현**:
  - `deleteIncorrectNote()` 내에서 조회한 `MemberIncorrectNote`가 `!isDeleted`인 경우에만 실질적인 논리 삭제(`note.delete()`)를 수행합니다.
  - 논리 삭제를 수행한 후, 해당 노트가 이미 자동 졸업되어 `isArchived` 상태가 아닌 경우에만 `MemberWeaknessIndex`를 찾아 `decrementForDeletion()`을 호출합니다. 이를 통해 이중 차감 및 졸업 항목에 대한 불필요한 차감을 방지하여 멱등성을 보장합니다.
  - **구현 의사 코드**:
    ```java
    if (!note.getIsDeleted()) {
        note.delete();
        if (!note.getIsArchived()) {
            weaknessIndexRepository.findByMemberIdAndLawReference(...)
                .ifPresent(MemberWeaknessIndex::decrementForDeletion);
        }
    }
    ```

---

### 2. 프론트엔드 (Flutter)

클라이언트는 로컬 SQLite DB 마이그레이션 구조를 설계하고, 오프라인 및 양방향 동기화에 대응하는 견고한 아웃박스 패턴을 TDD로 작성합니다.

#### [MODIFY] [pubspec.yaml](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/pubspec.yaml)
- `sqflite: ^2.3.0`, `sqflite_common_ffi: ^2.3.0`, `path: ^1.8.3` 디펜던시 추가.
- 네트워크 상태 감지용 `connectivity_plus: ^5.0.2` 디펜던시 추가.

#### [MODIFY] [main.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/main.dart)
- `main()` 함수 최상단에 데스크톱 플랫폼(Windows 및 Linux)을 모두 아우르는 FFI 초기화 코드를 추가합니다.
  ```dart
  import 'dart:io' show Platform;
  import 'package:sqflite_common_ffi/sqflite_ffi.dart';
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  ```

#### [NEW] [database_helper.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/core/database/database_helper.dart)
- 로컬 DB 생성 및 SQLite 버전 관리 (`version: 1`).
- 스키마 변경에 대응하는 `onUpgrade` 콜백 스케폴딩 선제적 구성.
- `client_incorrect_note` 로컬 테이블 생성 및 CRUD 트랜잭션 정의.

#### [MODIFY] [incorrect_note.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/incorrect_note/models/incorrect_note.dart)
- 기존 불리언 `isSynced` 필드를 완전히 **제거**하고, `syncStatus` 3-State Enum 필드로 교체 마이그레이션합니다.
  - `SyncStatus { synced, pendingDelete, pendingAdd }`
- SQLite 직렬화를 위해 `toMap()` 및 `fromMap()` 메서드에서 `syncStatus`를 문자열(String)로 원활하게 변환 및 역변환 처리합니다.

#### [NEW] [incorrect_note_provider_test.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/test/features/incorrect_note/incorrect_note_provider_test.dart)
- **TDD 선작성 케이스**:
  1. **Zombie Data 방지 테스트**: `loadNotes()` 호출 시 서버 응답 리스트 중 로컬 SQLite에 `pendingDelete`로 등록된 항목들이 UI 상태(`state`)에서 완벽하게 필터링되는지 검증.
  2. **오프라인 하드 딜리트 분기 테스트**: 서버 ID가 없고 `pendingAdd` 상태인 오답을 삭제 요청했을 때, 아웃박스 등록 없이 로컬 DB에서 즉각 하드 딜리트되는지 검증.
  3. **서버 오답 삭제 트랜지션 테스트**: 기존 서버 ID를 가진 오답을 삭제했을 때 로컬 DB 상태가 `pendingDelete`로 정상 업데이트되는지 검증.
  4. **백그라운드 동기화 정리 테스트**: `syncOutbox()`가 실행되어 서버 API 요청에 성공한 후, `pendingDelete` 항목이 로컬 DB에서 영구 하드 딜리트되는지 검증.

#### [MODIFY] [incorrect_note_provider.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/incorrect_note/providers/incorrect_note_provider.dart)
- 위 테스트 케이스들을 완벽히 만족하도록 `IncorrectNoteNotifier` 비즈니스 로직을 SQLite DB 연동 코드와 함께 구현합니다.
- **Zombie Data 방지 Merge 로직 적용**: `loadNotes()` 시 로컬 DB의 `PENDING_DELETE` 상태인 ID 목록을 조회하여, 서버 응답 데이터에서 필터링하는 병합 코드를 포함합니다.
  ```dart
  final serverNotes = await _fetchFromServer();
  final localPendingDeletes = await _db.getPendingDeleteIds();
  state = serverNotes.where((n) => !localPendingDeletes.contains(n.id)).toList();
  ```
- `connectivity_plus` 스트림을 구독하여 온라인 감지(`ConnectivityResult.none`이 아닐 때) 시 `syncOutbox()`를 즉각적으로 백그라운드 백로그 처리 연동합니다.

#### [MODIFY] [incorrect_note_screen.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/incorrect_note/views/incorrect_note_screen.dart)
- **Snappy UI 렌더링 도입**: 오답 삭제 카드에 `Dismissible` 위젯 또는 `AnimatedList`를 적용하여 삭제 시 화면 상에서 부드럽게 슬라이드아웃되며 사라지는 우수한 연출 효과를 추가합니다.

#### [MODIFY] [adaptive_quiz_clinic_screen.dart] (경로 미정, UI/Quiz 패키지 내 예상)
- **졸업 시 로컬 DB 반영**: 학습 화면에서 3회 연속 정답으로 졸업 처리될 경우, 로컬 SQLite DB의 아웃박스 상태에도 이를 반영하여 일관된 오프라인 사용자 경험을 유지합니다.

---

## 🧪 Verification Plan

### Automated Tests (TDD 기반)
- **백엔드**: `./gradlew test` 명령을 수행하여 선작성된 `ProgressServiceTest` 내 취약 지수 감면 및 이중 차감 방지 정합성 테스트 통과를 보장합니다.
- **프론트엔드**: `flutter test test/features/incorrect_note/incorrect_note_provider_test.dart` 명령을 수행하여 로컬 아웃박스 상태 전이 및 Zombie Data 방지 정합성 테스트 통과를 보장합니다.

### Manual Verification
1. **오프라인 모드 검증**: 네트워크가 끊긴 오프라인 환경에서 오답 삭제 시 화면에서 슬라이드아웃 애니메이션과 함께 즉각 삭제되고, 다시 로딩해도 나타나지 않는지(Zombie Data 방지 필터링 작동) 확인합니다.
2. **동기화 유효성 검증**: 네트워크 복구 시 `connectivity_plus` 감지를 통해 백그라운드 동기화가 자동 수행되며, 로컬 SQLite DB에서 `pendingDelete` 데이터가 하드 딜리트 클렌징되고, 서버의 취약 지수 점수가 안전하게 차감 반영되었는지 확인합니다.
3. **졸업 및 이중 삭제 복합 시나리오 검증**: 자동 졸업된 뒤 수동 삭제를 수행해도 서버 DB 멱등성이 완벽히 유지되어 추가 차감이 발생하지 않음을 교차 검증합니다.
