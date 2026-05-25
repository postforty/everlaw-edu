import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class AdaptiveQuizService {
  final Dio _dio;

  AdaptiveQuizService(this._dio);

  Future<String?> generateQuiz(String lawReference) async {
    try {
      final response = await _dio.post(
        '/quizzes/adaptive',
        data: {'lawReference': lawReference},
      );

      if (response.statusCode == 200) {
        return response.data['markdown'] as String?;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> submitQuiz(String lawReference, String answer) async {
    try {
      final response = await _dio.post(
        '/quizzes/submit',
        data: {
          'lawReference': lawReference,
          'answer': answer,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

final adaptiveQuizServiceProvider = Provider<AdaptiveQuizService>((ref) {
  final dio = ref.watch(dioProvider);
  return AdaptiveQuizService(dio);
});
