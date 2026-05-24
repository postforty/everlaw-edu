import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz_item.dart';
import '../../../core/network/dio_provider.dart';

final quizBankProvider = FutureProvider<List<QuizItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/api/v1/quizzes');
    final List data = response.data as List;
    return data.map((json) => QuizItem.fromJson(json)).toList();
  } catch (e) {
    return [];
  }
});
