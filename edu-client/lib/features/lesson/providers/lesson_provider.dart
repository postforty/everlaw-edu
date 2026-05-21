import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/lesson.dart';

// --- 로컬 모의 테스트를 위한 풍부한 고화질 Mock 데이터 정의 ---
final List<Lesson> _mockLessons = [
  Lesson(
    id: 1,
    curriculum: const Curriculum(
      id: 101,
      title: '중대재해처벌법과 현장 안전 관리',
      description: '경영책임자의 법적 의무 사항 및 사고 예방 실천 가이드',
      category: '산업안전',
      targetJobCategory: '생산·안전 경영책임자',
    ),
    title: '[최신 개정] 2026 중대재해처벌법 핵심 대응 및 현장 보건 확보 의무',
    contentMarkdown: '''
# [최신 개정] 2026 중대재해처벌법 핵심 대응 가이드

본 강좌는 경영책임자가 실질적으로 지배·운영·관리하는 사업장에서 임직원의 생명과 신체를 보호하기 위해 반드시 이행해야 할 법적 조치 사항을 다룹니다.

---

## ⚖️ 핵심 규정 분석

### 1. 경영책임자의 안전보건확보 의무 (제4조)
* **안전보건관리체계의 구축**: 재해예방에 필요한 인력 및 예산 편성 등 관리 체계를 갖추고 실제 이행해야 합니다.
* **재발방지 대책의 수립**: 중대산업재해가 발생한 경우 즉시 재발방지 및 시정 조치를 시행해야 합니다.
* **관계 법령에 따른 의무이행 관리**: 법정 교육 이행 및 위험성평가(Risk Assessment) 수립 여부를 상시 점검해야 합니다.

### 2. 위반 시의 형사 처벌 기준 (제6조)
* **경영책임자 개인 처벌**: 제4조의 의무를 위반하여 근로자 사망사고(중대산업재해)에 이르게 한 사업주 또는 경영책임자는 **1년 이상의 징역** 또는 **10억원 이하의 벌금**에 처해집니다. (징역과 벌금의 병과 가능)
* **법인 처벌**: 법인에게는 **50억원 이하의 벌금**이 부과됩니다.

---

## 💡 현장 핵심 실천 지침
1. **위험성평가 정기 실시**: 연 2회 이상 유해·위험 요인을 점검하고 개선 대책을 수립하십시오.
2. **비상대응 매뉴얼 구비**: 붕괴, 화재, 추락 등 중대 사고 상황 대비 비상 연락 체계 및 대피 훈련을 실시하십시오.
3. **임직원 의견 수렴**: 반기 1회 이상 현장 종사자의 안전 보건 관련 건의 사항을 수집하고 적절한 예산을 투입해 조치하십시오.

---

### 📝 [QUIZ] 중대재해처벌법 제6조에 의거하여, 사업주가 안전 보건 확보 의무를 위반함으로써 근로자 사망 등 중대산업재해가 발생했을 때, 경영책임자 개인에게 부과될 수 있는 형사 처벌의 최소 징역 기준은 어떻게 될까요?
1) 6개월 이상의 징역
2) 1년 이상의 징역
3) 3년 이상의 징역
4) 5년 이상의 징역
''',
    associatedLawReference: '중대재해처벌법 제4조 및 제6조',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Lesson(
    id: 2,
    curriculum: const Curriculum(
      id: 102,
      title: '근로기준법 연장 근로 규제 가이드',
      description: '주 52시간 근무제의 예외 및 유연근무 도입 실무',
      category: '인사노무',
      targetJobCategory: '인사팀 및 현업 부서장',
    ),
    title: '2026 개정 근로기준법: 52시간제 연장 근로 위반 예방 및 유연근무 실무',
    contentMarkdown: '''
# 2026 근로기준법: 연장 근로 및 유연근무 실무 지침

본 강좌는 법정근로시간 위반을 철저히 방지하고, 유연하고 합법적인 업무 프로세스를 구축하고자 하는 인사 담당자 및 조직 리더를 위한 실무 강좌입니다.

---

## ⚖️ 핵심 규정 분석

### 1. 연장 근로의 법적 제한 (제53조)
* **당사자 합의 원칙**: 사용자와 근로자 간의 개별적인 합의가 있는 경우에 한하여 1주간에 **최대 12시간**을 한도로 근로시간을 연장할 수 있습니다.
* **주 52시간제 원칙**: 법정근로시간(1주 40시간) + 합법적 연장근로(1주 12시간)의 한도를 초과할 수 없습니다.

### 2. 위반 시의 형사 처벌 (제110조)
* 1주 12시간의 연장 근로 제한을 위반하여 근로를 지속시킨 자는 **2년 이하의 징역** 또는 **2천만원 이하의 벌금**에 처해집니다.
* 합의 없는 연장 근로나 강요된 추가 근무 역시 강력한 노동법 위반 소송 사유가 됩니다.

---

## 💡 유연근무제 합법 도입 방안
1. **탄력적 근로시간제**: 특정 주의 근로시간을 늘리는 대신 다른 주의 근로시간을 단축하여 평균 1주 근로시간을 40시간 이내로 조정하십시오. (최대 3개월 또는 6개월 단위)
2. **선택적 근로시간제**: 근로자 스스로 출퇴근 시간을 자유롭게 결정하도록 하되, 1개월(연구개발 업무의 경우 3개월) 정산 기간 내 평균 주 40시간 한도를 엄수하십시오.

---

### 📝 [QUIZ] 근로기준법 제53조 제1항에 규정된 법정 요건에 따르면, 노사 당사자 간의 합의가 있는 경우 1주간에 연장할 수 있는 합법적인 근로시간의 최대 한도는 몇 시간일까요?
1) 8시간
2) 12시간
3) 15시간
4) 20시간
''',
    associatedLawReference: '근로기준법 제53조 및 제110조',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
];

/// 임직원 맞춤형 최신 교안 목록을 패치하는 FutureProvider (네트워크 에러 시 Mock 데이터 반환)
final lessonsListProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get('/api/v1/lessons');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
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
  Future<void> submitAnswer(int lessonId, String selectedAnswer) async {
    state = const AsyncValue.loading();
    final dio = _ref.read(dioProvider);

    try {
      final response = await dio.post(
        '/api/v1/lessons/quiz/submit',
        data: {
          'lessonId': lessonId,
          'selectedAnswer': selectedAnswer,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        state = AsyncValue.data(data);
      } else {
        throw Exception(response.statusMessage ?? '퀴즈 채점 에러');
      }
    } catch (e, stack) {
      // 1초간 채점 중인 느낌의 딜레이를 제공한 뒤 오프라인 로컬 채점 수행
      await Future.delayed(const Duration(milliseconds: 1000));
      
      bool isCorrect = false;
      String feedback = '';
      String correctAnswer = '';

      if (lessonId == 1) {
        correctAnswer = '2'; // 1년 이상의 징역
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 중대재해처벌법 제6조 제1항에 의거하여, 안전보건확보 의무를 다하지 않아 중대산업재해로 근로자 사망이 유발되었을 때 경영책임자는 "1년 이상의 징역 또는 10억원 이하의 벌금"의 형사 처벌 대상이 됩니다. 법인은 50억원 이하 벌금입니다.'
            : '아쉽게도 오답입니다. 정답은 2번(1년 이상의 징역)입니다. 중대재해처벌법 제6조 제1항은 사망 사고 시 처벌 하한선을 "1년 이상의 유기징역"으로 엄격하게 규정하고 있습니다.';
      } else if (lessonId == 2) {
        correctAnswer = '2'; // 12시간
        isCorrect = selectedAnswer.trim() == correctAnswer;
        feedback = isCorrect
            ? '정답입니다! 근로기준법 제53조 제1항에 명시된 대로, 당사자 간의 합의가 있는 경우 1주간에 최대 12시간을 한도로 법정근로시간(40시간)을 늘릴 수 있어 주 총 52시간제가 완성됩니다.'
            : '아쉽게도 오답입니다. 정답은 2번(12시간)입니다. 당사자 간 합의 시 1주간에 연장할 수 있는 최대 법적 연장근로 한도는 12시간입니다.';
      } else {
        isCorrect = true;
        feedback = '데모 강좌 평가가 성공적으로 수행되었습니다.';
      }

      state = AsyncValue.data({
        'isCorrect': isCorrect,
        'feedback': feedback,
        'correctAnswer': correctAnswer,
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
