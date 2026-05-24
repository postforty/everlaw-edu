import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/features/incorrect_note/providers/adaptive_quiz_provider.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('Adaptive Quiz Service Test', () {
    late MockDio mockDio;
    late AdaptiveQuizService service;

    setUp(() {
      mockDio = MockDio();
      service = AdaptiveQuizService(mockDio);
    });

    test('generateQuiz fetches markdown quiz', () async {
      when(() => mockDio.post('/api/v1/quizzes/adaptive', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/quizzes/adaptive'),
                data: {'markdown': '### AI Quiz'},
                statusCode: 200,
              ));

      final result = await service.generateQuiz('law1');

      expect(result, '### AI Quiz');
      verify(() => mockDio.post('/api/v1/quizzes/adaptive', data: {'lawReference': 'law1'})).called(1);
    });

    test('submitQuiz returns feedback', () async {
      when(() => mockDio.post('/api/v1/quizzes/submit', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/quizzes/submit'),
                data: {
                  'isCorrect': true,
                  'feedback': 'Good job',
                  'metaCognitionStatus': 'safe',
                },
                statusCode: 200,
              ));

      final feedback = await service.submitQuiz('law1', 'my answer');

      expect(feedback!['isCorrect'], isTrue);
      expect(feedback['feedback'], 'Good job');
      verify(() => mockDio.post('/api/v1/quizzes/submit', data: {
        'lawReference': 'law1',
        'answer': 'my answer',
      })).called(1);
    });
  });
}
