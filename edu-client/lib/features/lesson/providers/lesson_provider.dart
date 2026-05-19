import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/lesson.dart';

/// 임직원 맞춤형 최신 교안 목록을 패치하는 FutureProvider
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
    throw Exception('수강 가능한 최신 교안을 불러올 수 없습니다: $e');
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
    throw Exception('교안 콘텐츠 로드 실패: $e');
  }
});

/// 모의 평가 퀴즈 채점 결과를 보관 및 처리하는 StateNotifier
class QuizSubmissionNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref _ref;

  QuizSubmissionNotifier(this._ref) : super(const AsyncValue.data(null));

  /// 퀴즈 답안 제출 및 실시간 평가 API 호출
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
      state = AsyncValue.error(e, stack);
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
