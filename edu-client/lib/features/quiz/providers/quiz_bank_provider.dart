import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz_item.dart';
import '../../../core/network/dio_provider.dart';

final quizBankProvider = FutureProvider<List<QuizItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/quizzes');
    final List data = response.data as List;
    return data.map((json) => QuizItem.fromJson(json)).toList();
  } catch (e, stackTrace) {
    print('Failed to fetch quiz bank: $e');
    print(stackTrace);
    throw Exception('Failed to load quiz feed from server: $e');
  }
});
