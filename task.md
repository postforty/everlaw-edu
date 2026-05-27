# [U-7] 오답노트 개별 삭제 및 취약 지수 연동 기능 구현 작업 목록

## 1. 백엔드 (Spring Boot) 구현
- [x] `ProgressServiceTest.java` (TDD 기반 테스트 작성)
  - [x] 정상 삭제 및 취약 지수 차감(-5.0) 검증
  - [x] 이중 차감 방지 검증 (중복 요청 시)
  - [x] 졸업(isArchived=true) 상태 항목 삭제 시 차감 무시 검증
- [x] `MemberWeaknessIndex.java` 수정
  - [x] `decrementForDeletion()` 메서드 추가 (최하점 0점 방어 포함)
  - [x] 누적 통계(`consecutiveCorrects`, `incorrectCount`) 유지 보장
- [x] `ProgressService.java` 비즈니스 로직 구현
  - [x] `deleteIncorrectNote()` 내 논리 삭제(`!isDeleted`) 방어 로직 추가
  - [x] 아카이브(`!isArchived`) 분기 처리 및 취약 지수 차감 연동

## 2. 프론트엔드 (Flutter) 구현
- [x] 디펜던시 및 초기 설정
  - [x] `pubspec.yaml`에 `sqflite`, `connectivity_plus` 패키지 추가
  - [x] `main.dart` 내 데스크톱 플랫폼(Windows/Linux) FFI 초기화 코드 추가
- [x] 로컬 DB 구축 및 모델링
  - [x] `database_helper.dart` 생성 (스키마 설정 및 CRUD)
  - [x] `incorrect_note.dart` 모델 마이그레이션 (`isSynced` -> `syncStatus` Enum)
- [x] 비즈니스 로직 (TDD 기반)
  - [x] `incorrect_note_provider_test.dart` 테스트 작성 (좀비 데이터 방어, 오프라인 삭제 등)
  - [x] `incorrect_note_provider.dart` 내 Zombie Data 필터링 병합 로직 추가
  - [x] `incorrect_note_provider.dart` 내 `connectivity_plus` 활용 백그라운드 동기화 구현
- [x] UI 및 연동
  - [x] `incorrect_note_screen.dart` 내 슬라이드아웃 삭제 애니메이션(`Dismissible` 등) 추가
  - [x] `adaptive_quiz_clinic_screen.dart` 내 졸업 시 로컬 DB 상태 연동

## 3. 검증 (Verification)
- [x] 백엔드 단위 테스트 (`./gradlew test`) 전체 통과 확인
- [x] 프론트엔드 단위 테스트 (`flutter test`) 전체 통과 확인
- [ ] 수동 통합 테스트 (오프라인 삭제 동작, 네트워크 복구 시 동기화 멱등성 검증)
