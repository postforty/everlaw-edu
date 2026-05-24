import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_client/features/quiz/models/quiz_item.dart';
import 'package:edu_client/features/quiz/providers/quiz_bank_provider.dart';
import 'package:edu_client/core/network/dio_provider.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('Quiz Bank Provider Test', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    test('fromJson 직렬화 테스트', () {
      final json = {
        'id': 'q1',
        'question': '질문',
        'options': ['1', '2', '3', '4'],
        'correctAnswer': '3',
        'explanation': '해설',
        'lawReference': '참조법령'
      };

      final quiz = QuizItem.fromJson(json);

      expect(quiz.id, 'q1');
      expect(quiz.question, '질문');
      expect(quiz.options.length, 4);
      expect(quiz.correctAnswer, '3');
      expect(quiz.explanation, '해설');
      expect(quiz.lawReference, '참조법령');
    });

    test('quizBankProvider가 /api/v1/quizzes에서 데이터를 가져오는지 테스트', () async {
      final mockData = [
        {
          'id': 'q1',
          'question': '질문',
          'options': ['1', '2', '3', '4'],
          'correctAnswer': '3',
          'explanation': '해설',
          'lawReference': '참조법령'
        }
      ];

      when(() => mockDio.get('/api/v1/quizzes'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/quizzes'),
                data: mockData,
                statusCode: 200,
              ));

      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
        ],
      );

      final quizzes = await container.read(quizBankProvider.future);

      expect(quizzes.length, 1);
      expect(quizzes.first.id, 'q1');
    });
  });
}
