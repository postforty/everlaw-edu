import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/features/incorrect_note/providers/incorrect_note_provider.dart';
import 'package:edu_client/features/incorrect_note/models/incorrect_note.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('IncorrectNoteNotifier Test', () {
    late MockDio mockDio;
    late IncorrectNoteNotifier notifier;

    setUp(() {
      mockDio = MockDio();
    });

    test('loadNotes fetches from API', () async {
      when(() => mockDio.get('/api/v1/progress/incorrect-notes'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/progress/incorrect-notes'),
                data: [
                  {
                    'id': 'note1',
                    'quizId': 'quiz1',
                    'question': 'Q1',
                    'options': ['1', '2'],
                    'answerIndex': 0,
                    'selectedIndex': 1,
                    'explanation': 'exp',
                    'lawReference': 'law1',
                    'incorrectAt': '2026-05-24T00:00:00Z',
                    'isArchived': false
                  }
                ],
                statusCode: 200,
              ));

      notifier = IncorrectNoteNotifier(mockDio);
      
      // Wait for the constructor's async call to finish
      await Future.delayed(Duration.zero);

      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, 'note1');
      verify(() => mockDio.get('/api/v1/progress/incorrect-notes')).called(1);
    });

    test('registerQuizResult posts result to API', () async {
      when(() => mockDio.get('/api/v1/progress/incorrect-notes'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/progress/incorrect-notes'),
                data: [],
                statusCode: 200,
              ));
      notifier = IncorrectNoteNotifier(mockDio);

      when(() => mockDio.post('/api/v1/progress/quiz-result', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/progress/quiz-result'),
                data: {'masteryAchieved': true},
                statusCode: 200,
              ));

      final result = await notifier.submitQuizResult('law1', true);

      expect(result, isTrue); // expects true because API returned masteryAchieved: true
      verify(() => mockDio.post('/api/v1/progress/quiz-result', data: {
        'lawReference': 'law1',
        'isCorrect': true,
      })).called(1);
    });
  });
}
