import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/lesson.dart';

// --- 로컬 모의 테스트를 위한 풍부한 고화질 Mock 데이터 정의 ---
final List<Lesson> _mockLessons = [
  Lesson(
    id: 1,
    curriculum: const Curriculum(
      id: 101,
      title: '산업안전보건법 총칙 및 보건의무',
      description: '산업안전보건법의 기본 목적과 정부·사업주 보건 의무',
      category: '안전보건',
      targetJobCategory: '전직원 및 관리자',
    ),
    title: '[마스터 챕터 1] 산업안전보건법 총칙 및 핵심 주체별 기본 안전 의무',
    contentMarkdown: '''
# 산업안전보건법 총칙 및 기본 보건 의무

본 강좌는 산업안전보건법의 근간을 이루는 목적과 각 주체(정부, 사업주, 근로자)의 기본 의무 사항을 학습합니다.

---

## ⚖️ 핵심 규정 분석

### 1. 산업안전보건법의 목적 (제1조)
* 산업안전 및 보건에 관한 기준을 확립하고, 그 책임의 한계를 명확하게 하여 **산업재해를 예방**합니다.
* 쾌적한 작업환경을 조성함으로써 근로자의 **안전 및 보건을 유지·증진**하는 것을 목적으로 합니다.

### 2. 사업주의 기본 의무 (제5조)
* 근로자의 안전 및 건강 유지·증진을 위한 국가 정책에 따라야 합니다.
* 유해·위험요인을 찾아내어 안전조치를 취하고, **쾌적한 작업환경**을 제공할 책임이 있습니다.
* 안전보건 정보를 근로자에게 성실히 제공해야 합니다.

### 3. 근로자의 기본 의무 (제6조)
* 근로자는 법이 정하는 **산업재해 예방을 위한 기준을 반드시 준수**해야 합니다.
* 사업주 또는 관계인이 실시하는 산업재해 예방 조치에 성실히 협조해야 합니다. (예: 안전모 착용, 보호구 의무)

---

### 📝 [QUIZ] 산업안전보건법 제5조 및 제6조에 규정된 내용 중, '산업재해 예방을 위한 기준을 준수하고 사업주의 예방 조치에 협조해야 할 의무'를 지닌 주체는 누구일까요?
1) 정부 부처 공무원
2) 사업주 및 최고 경영자
3) 근로자 본인
4) 산업안전보건공단
''',
    associatedLawReference: '산업안전보건법 제1조 ~ 제6조',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    isRecentlyRevised: false,
    revisionNumber: 1,
  ),
  Lesson(
    id: 2,
    curriculum: const Curriculum(
      id: 102,
      title: '위험성평가 실무',
      description: '스스로 유해·위험요인을 찾아내어 개선하는 핵심 프로세스',
      category: '안전보건',
      targetJobCategory: '안전관리자 및 현장 감독관',
    ),
    title: '[마스터 챕터 2] 현장 위험성평가(Risk Assessment) 구축 및 실무 가이드',
    contentMarkdown: '''
# 현장 위험성평가(Risk Assessment) 구축 실무

위험성평가는 사업장의 위험 요인을 미리 찾아내어 그 위험의 크기를 평가하고, 적절한 감소 대책을 실행하는 예방 활동입니다.

---

## ⚖️ 핵심 규정 분석

### 1. 위험성평가의 의무 실시 (제36조)
* 사업주는 건설물, 기계, 설비, 원재료, 가스, 수증기, 분진 등에 따른 유해·위험 요인을 스스로 찾아내야 합니다.
* 위험 요인별 부상 또는 질병 발생 가능성(빈도)과 중대성(강도)을 평가해야 합니다.
* 위험 감소 대책을 마련하여 실천해야 하며, **근로자를 평가 과정에 참여**시켜야 합니다.

### 2. 위험성평가의 기록 및 보존
* 위험성평가를 시행한 경우, 그 기록을 최소 **3년간 보존**해야 합니다.
* 기록에는 유해·위험요인 파악 결과, 위험성 결정 내용, 조치한 대책 내용 등이 구체적으로 포함되어야 합니다.

---

## 💡 실무 위험성평가 프로세스
1. **사전 준비**: 평가 대상을 선정하고, 유관 정보를 수집합니다.
2. **유해·위험요인 파악**: 체크리스트법, 순회 점검 등을 통해 유해 위험요인을 현출합니다.
3. **위험성 결정**: 빈도와 강도를 조합해 위험 수준이 허용 가능한지 결정합니다.
4. **위험성 감소대책 수립 및 실행**: 공학적 대책, 관리적 대책, 보호구 지급 순으로 해소합니다.

---

### 📝 [QUIZ] 산업안전보건법 제36조에 따라, 사업장에서 유해·위험 요인별 위험성평가를 완료한 경우, 관련 평가 기록물을 법적으로 최소 몇 년 동안 보존해야 할까요?
1) 1년
2) 2년
3) 3년
4) 5년
''',
    associatedLawReference: '산업안전보건법 제36조',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    isRecentlyRevised: false,
    revisionNumber: 1,
  ),
  Lesson(
    id: 3,
    curriculum: const Curriculum(
      id: 103,
      title: '고소 작업 및 비계 조치',
      description: '추락 사고 예방을 위한 높이별 비계 규격 및 발판 설치 지침',
      category: '안전보건',
      targetJobCategory: '현장 작업자 및 안전팀',
    ),
    title: '[마스터 챕터 3] 고소 작업 시 추락 방지 안전망 및 비계 설치 안전 기준',
    contentMarkdown: '''
# [⚖️ 2026 개정법 반영] 고소 작업 및 비계 설치 안전 기준

본 강좌는 추락 위험이 높은 장소에서 작업 시 근로자의 생명을 보호하기 위한 필수 물리적 안전조치를 다룹니다.

---

## ⚖️ 핵심 규정 분석

### 1. 비계 작업 시 추락 방지 조치 의무 (제38조)
* 높이가 **2미터(2m) 이상**의 장소(작업발판 및 비계 등)에서 작업을 진행할 때, 추락 위험이 있는 경우 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치하거나 안전대를 착용하게 해야 합니다.
* **[🚨 2026 핵심 개정 사항]** 기존의 느슨한 기준이었던 3미터(3m) 이상에서, 2026년 법 개정을 통해 **2미터(2m) 이상**으로 규제가 대폭 강화되었습니다!

### 2. 비계 및 작업발판 설치 기준
* **작업발판 폭**: 작업발판의 폭은 최소 40cm 이상이어야 하며, 발판 틈새는 3cm 이하로 촘촘히 고정해야 합니다.
* **안전난간 설치**: 바닥으로부터 90cm 이상 높이의 상부 난간대와 중간 난간대를 견고히 설치해야 합니다.

---

### 📝 [QUIZ] 2026년 최신 개정된 산업안전보건법에 의거하여, 현장 비계 작업 시 근로자의 추락 위험을 예방하기 위해 추락 방지망을 의무적으로 설치해야 하는 작업 장소의 최소 높이 기준은 무엇입니까?
1) 1미터(1m) 이상
2) 2미터(2m) 이상
3) 3미터(3m) 이상
4) 5미터(5m) 이상
''',
    associatedLawReference: '산업안전보건법 제38조',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    isRecentlyRevised: true,
    revisionNumber: 2,
  ),
  Lesson(
    id: 4,
    curriculum: const Curriculum(
      id: 104,
      title: '벌금 및 형사처벌',
      description: '안전 조치 위반에 따른 법인 및 행위자 처벌 수위 총정리',
      category: '안전보건',
      targetJobCategory: '경영진 및 현장 대리인',
    ),
    title: '[마스터 챕터 4] 산업안전보건법 위반 시 벌칙, 벌금 및 형사처벌 기준',
    contentMarkdown: '''
# 산업안전보건법 위반 시 형사처벌 및 양벌규정

산업안전보건법상의 안전 및 보건조치 의무를 게을리하여 근로자가 중대한 위해를 입은 경우, 엄격한 형사처벌과 금전적 징벌이 내려집니다.

---

## ⚖️ 핵심 규정 분석

### 1. 안전조치 의무 위반으로 근로자 사망 시 (제167조)
* 사업주 또는 경영책임자가 안전조치 의무를 위반하여 근로자를 사망에 이르게 한 경우, **7년 이하의 징역** 또는 **1억원 이하의 벌금**에 처해집니다.
* 형 확정 후 5년 이내에 동일한 죄를 다시 범한 경우에는 그 형의 2분의 1까지 가중 처벌을 받습니다.

### 2. 안전조치 의무 위반 시 (일반 재해 미발생 시) (제168조)
* 실제 사망사고가 나지 않았더라도, 법정 안전조치 의무(예: 방호장치 미설치, 추락망 미설치 등)를 위반한 사실만으로도 **5년 이하의 징역** 또는 **5천만원 이하의 벌금**에 처해집니다.

### 3. 법인 처벌 (양벌규정 - 제173조)
* 행위자 처벌 외에 법인에게도 **10억원 이하(사망사고 시)** 또는 **5천만원 이하(일반 의무 위반 시)**의 벌금을 병과하여 경제적 책임을 강하게 묻습니다.

---

### 📝 [QUIZ] 산업안전보건법 제167조에 근거하여, 사업주가 필수 안전조치 의무를 위반함으로써 현장 근로자를 사망에 이르게 한 중대재해 발생 시, 사업주에게 부과되는 형사 처벌의 최고 기준은 어떻게 될까요?
1) 1년 이하의 징역 또는 1천만원 이하의 벌금
2) 3년 이하의 징역 또는 3천만원 이하의 벌금
3) 5년 이하의 징역 또는 5천만원 이하의 벌금
4) 7년 이하의 징역 또는 1억원 이하의 벌금
''',
    associatedLawReference: '산업안전보건법 제167조 ~ 제173조',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    isRecentlyRevised: false,
    revisionNumber: 1,
  ),
];

/// 임직원 맞춤형 최신 교안 목록을 패치하는 FutureProvider (네트워크 에러 시 Mock 데이터 반환)
final lessonsListProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get('/api/v1/lessons');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      if (data.isEmpty) {
        // 서버의 데이터베이스가 비어있을 경우, 사용자 테스트 편의를 위해 고품질 데모 데이터를 리턴
        return _mockLessons;
      }
      return data.map((json) => Lesson.fromJson(json)).toList();
    } else {
      throw Exception('교안 목록 패치 실패: ${response.statusMessage}');
    }
  } catch (e) {
    // 백엔드 미구동 등 연결 오류 시 고해상도 데모 데이터를 즉시 리턴
    return _mockLessons;
  }
});

/// 특정 교안의 상세 마크다운 본문을 패치하는 FutureProvider.family
final lessonDetailProvider = FutureProvider.autoDispose.family<Lesson, int>((ref, lessonId) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get('/api/v1/lessons/$lessonId');
    if (response.statusCode == 200) {
      return Lesson.fromJson(response.data);
    } else {
      throw Exception('교안 상세 패치 실패: ${response.statusMessage}');
    }
  } catch (e) {
    // 백엔드 연결 오류 시 해당 ID에 대응하는 상세 Mock 로드
    final matched = _mockLessons.firstWhere(
      (l) => l.id == lessonId,
      orElse: () => _mockLessons.first,
    );
    return matched;
  }
});

/// 모의 평가 퀴즈 채점 결과를 보관 및 처리하는 StateNotifier
class QuizSubmissionNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref _ref;

  QuizSubmissionNotifier(this._ref) : super(const AsyncValue.data(null));

  /// 퀴즈 답안 제출 및 실시간 평가 API 호출 (실패 시 로컬 채점 Fallback 작동)
  Future<void> submitAnswer(int lessonId, String selectedAnswer, String confidenceLevel) async {
    state = const AsyncValue.loading();
    final dio = _ref.read(dioProvider);

    try {
      final response = await dio.post(
        '/api/v1/lessons/quiz/submit',
        data: {
          'lessonId': lessonId,
          'selectedAnswer': selectedAnswer,
          'confidenceLevel': confidenceLevel,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        state = AsyncValue.data(data);
      } else {
        throw Exception(response.statusMessage ?? '퀴즈 채점 에러');
      }
    } catch (e) {
      // 1초간 채점 중인 느낌의 딜레이를 제공한 뒤 오프라인 로컬 채점 수행
      await Future.delayed(const Duration(milliseconds: 1000));
      
      bool isCorrect = false;
      String feedback = '';
      String correctAnswer = '';

      if (lessonId == 1) {
        correctAnswer = '3'; // 근로자 본인
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 산업안전보건법 제5조 및 제6조에 따라 근로자는 산업재해 예방을 위한 기준을 준수하고 협조해야 할 의무가 있으며, 안전보건관리책임자의 임명 등 관리 체계 구축은 근로자가 아닌 사업주의 고유 의무입니다.'
            : '아쉽게도 오답입니다. 정답은 3번(근로자 본인)이 협조의 주체이지만, 안전보건관리책임자 임명은 사업주의 의무이기 때문에 문항의 의무 주체에 해당하지 않습니다.';
      } else if (lessonId == 2) {
        correctAnswer = '3'; // 3년
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 산업안전보건법 제36조 제2항에 따라 위험성평가를 완료한 경우, 유해·위험요인 파악 및 감소대책 수립 등에 관한 기록물을 3년 동안 성실히 보존해야 합니다.'
            : '아쉽게도 오답입니다. 정답은 3번(3년)입니다. 위험성평가 시행 기록의 법정 보존 의무 기간은 최소 3년입니다.';
      } else if (lessonId == 3) {
        correctAnswer = '2'; // 2m 이상
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 2026년 최신 개정법에 따라 고소 비계 작업 시 추락 방지 안전망을 의무 설치해야 하는 장소의 최소 높이 기준이 기존 3m에서 2m 이상으로 대폭 강화되었습니다.'
            : '아쉽게도 오답입니다. 정답은 2번(2미터 이상)입니다. 2026년 법률 개정을 통해 안전망 의무 설치 기준 높이가 2m 이상으로 강화되었습니다.';
      } else if (lessonId == 4) {
        correctAnswer = '4'; // 7년 이하의 징역 또는 1억원 이하의 벌금
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 산업안전보건법 제167조에 따라, 사업주가 안전조치 의무를 위반하여 근로자를 사망하게 한 경우 7년 이하의 징역 또는 1억원 이하의 벌금에 처해집니다.'
            : '아쉽게도 오답입니다. 정답은 4번(7년 이하의 징역 또는 1억원 이하의 벌금)입니다. 이는 매우 무거운 처벌 수위를 부과합니다.';
      } else {
        isCorrect = true;
        feedback = '데모 강좌 평가가 성공적으로 수행되었습니다.';
      }

      // 메타인지 교차 분석 진단 로직
      String metaCognitionStatus = 'safe';
      if (isCorrect) {
        if (confidenceLevel == 'CONFIDENT') {
          metaCognitionStatus = 'safe'; // 안전 지대 (알고 맞춤)
        } else {
          metaCognitionStatus = 'warning_guessed'; // 보완 구역 (찍어서 맞춤)
        }
      } else {
        if (confidenceLevel == 'CONFIDENT') {
          metaCognitionStatus = 'warning_illusion'; // 착각 위험 구역 (안다고 생각하고 틀림)
        } else {
          metaCognitionStatus = 'danger_unknown'; // 재학습 구역 (모르고 틀림)
        }
      }

      state = AsyncValue.data({
        'isCorrect': isCorrect,
        'feedback': feedback,
        'correctAnswer': correctAnswer,
        'metaCognitionStatus': metaCognitionStatus,
        'offlineMode': true,
      });
    }
  }

  /// 퀴즈 상태 리셋 (다시 풀기 등)
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// 퀴즈 채점 상태 공급용 StateNotifierProvider
final quizSubmissionNotifierProvider = StateNotifierProvider.autoDispose<QuizSubmissionNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return QuizSubmissionNotifier(ref);
});
