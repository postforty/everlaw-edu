# 🚀 산업안전보건법 마스터 커리큘럼 & 실시간 개정 핫스왑(Hot-Swap) 구현 계획서

본 계획서는 사용자가 제안하시고 승인하신 핵심 가치인 **"산업안전보건법 전반에 대한 상시 학습 체계"**를 기본 구축하고, 법령 개정 시 관련 챕터의 본문과 퀴즈가 **실시간으로 AI에 의해 갱신(Hot-Swap) 및 동기화**되도록 AI 엔진과 클라이언트 애플리케이션의 아키텍처를 전면 고도화하기 위한 상세 개발 로드맵입니다.

---

## 📌 1. 핵심 구현 목표

1. **상시 마스터 커리큘럼(Core Curriculum Map) 정립**:
   * 산업안전보건법 전반을 관통하는 **4가지 핵심 마스터 챕터**를 기본 시딩(Base Seeding)하여 상시 개설합니다.
   * `챕터 1: 총칙 및 보건의무` | `챕터 2: 위험성평가 실무` | `챕터 3: 고소 작업 및 비계 조치` | `챕터 4: 벌금 및 형사처벌`
2. **실시간 지식 핫스왑(Hot-Swap) 아키텍처 구현 (AI 엔진)**:
   * 개정 법령 스캔 시, RAG 검색을 통해 **연관된 마스터 챕터를 역추적하여 매칭**합니다.
   * AI(Gemini 3.1)는 연관 챕터의 구버전 강의안과 개정안을 차분 분석(Diff Analysis)하여 **최신화된 리비전(Revision) 본문 및 개정형 평가 퀴즈**를 자동으로 리라이팅(Rewriting) 재생산합니다.
   * 자가 검증 통과 후 결재함을 거쳐 승인 시 데이터베이스의 해당 마스터 챕터 데이터가 **실시간으로 핫스왑 교체**됩니다.
3. **학습자 최신 개정 뱃지 및 리마인드 UI/UX 반영 (클라이언트)**:
   * 핫스왑 완료된 최신 챕터에 **`⚖️ 2026 개정법 반영 완료`** 혹은 **`💡 실시간 갱신 완료`** 라는 수려한 그라데이션 뱃지를 부착합니다.
   * 법 개정으로 퀴즈가 갱신된 경우 **"법령이 최근 개정되어 퀴즈가 새롭게 갱신되었습니다. 다시 풀어보세요!"** 라는 메타인지 리마인드 알림을 제공합니다.

---

## 📂 2. 컴포넌트별 세부 변경안

### 2.1 [AI Engine] [MODIFY] [generator.py](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/ai-engine/app/services/generator.py)
* **챕터 핫스왑 매칭 알고리즘**:
  * 입력된 개정 법령을 바탕으로 벡터스토어(`curriculum_documents`) 내에 시딩된 마스터 챕터 목록을 타겟팅하여 가장 관련도가 높은 기존 챕터의 본문 텍스트를 불러옵니다.
* **리라이팅 및 개정 퀴즈 생산**:
  * Gemini 3.1 프롬프트를 변경하여 기존 마스터 강의안에서 모순이나 오류가 발생하는 부분(예: 3m 높이 제한)을 정밀 정정하여 매끄럽게 흐르는 최신 강의 마크다운 본문과 개정형 퀴즈를 JSON 스키마로 배출하도록 수정합니다.

### 2.2 [AI Engine] [MODIFY] [seed.py](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/ai-engine/scripts/seed.py)
* 마스터 챕터 4종(`챕터 1 ~ 4`)의 상세 마크다운 본문과 퀴즈 초기 버전 데이터를 벡터 스토어(`curriculum_documents` 및 RAG DB)에 **마스터 뼈대 데이터로 기본 벌크 적재**하는 로직을 보강합니다.

### 2.3 [Client] [MODIFY] [lesson_provider.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/lesson/providers/lesson_provider.dart)
* **테스트용 마스터 데이터 개편**:
  * 로컬 `_mockLessons` 데모 데이터를 단편 강좌가 아닌 **산업안전보건법 4대 마스터 챕터 구성**으로 전면 재구조화합니다.
  * 각 마스터 강좌 객체에 `isRecentlyRevised` (최근 개정 여부), `revisionNumber` (리비전 차수) 메타 필드를 추가하여 핫스왑 이력을 UI단에 흘려보냅니다.

### 2.4 [Client] [MODIFY] [lesson_list_screen.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/lesson/views/lesson_list_screen.dart)
* **상시 학습 목차 UI 구성**:
  * 4대 마스터 챕터 목록을 체계적인 커리큘럼 리스트로 시각화합니다.
* **최신 개정 뱃지 장착**:
  * 핫스왑 이력(`isRecentlyRevised`가 true인 항목)에 은은하게 박동 애니메이션(Pulse) 또는 메탈릭 그라데이션이 흐르는 **`⚖️ 2026 최신 개정`** 명품 뱃지를 장착합니다.

### 2.5 [Client] [MODIFY] [lesson_detail_screen.dart](file:///c:/Users/dandycode/Documents/GitHub/everlaw-edu/edu-client/lib/features/lesson/views/lesson_detail_screen.dart)
* **메타인지 재도전 알림**:
  * 사용자가 예전에 이 과목의 퀴즈를 풀었으나 법령 개정으로 인해 버전이 갱신되었을 때, 퀴즈 영역 상단에 노란색 비상 보조 패널로 **"법이 최근 개정되어 퀴즈가 새로 갱신되었습니다. 자신의 지식을 다시 한번 확인해 보세요!"** 리마인드 팁 카드를 출력합니다.

---

## 🧪 3. 종합 검증 계획 (Verification Plan)

### 3.1 백그라운드 AI 핫스왑 E2E 테스트
* `uv run python -X utf8 test_rag.py` 기동 시, AI가 기존 3번 챕터(비계 규정)를 완벽하게 역매칭해 찾아내고, 개정 법령(3m ➡️ 2m 강화) 수치를 정확히 융합하여 핫스왑된 **'수정 마스터 교안 및 2m가 정답인 신규 퀴즈'**가 콘솔에 무오류로 배출되는지 증명합니다.

### 3.2 브라우저 UI/UX 실무 검증
1. **상시 커리큘럼 구성**: 홈 화면에서 산업안전보건법 1장부터 4장까지의 상시 학습 트랙이 일관되게 정렬되어 있는지 확인.
2. **핫스왑 뱃지 노출**: 최근 개정된 챕터 카드 옆에 수려한 **`⚖️ 2026 최신 개정`** 실시간 뱃지가 깨짐 없이 모던하게 노출되는지 점검.
3. **퀴즈 갱신 리마인더**: 퀴즈 상세 페이지 진입 시, 개정 이력에 따른 재풀이 유도 팁 패널의 글래스모피즘 아웃라인 및 가독성을 브라우저 해상도별로 정밀 체크.
