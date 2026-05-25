import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/features/chatbot/providers/chatbot_provider.dart';
import 'package:edu_client/features/chatbot/models/chat_message.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('ChatbotNotifier Test', () {
    late MockDio mockDio;
    late ChatbotNotifier notifier;

    setUp(() {
      mockDio = MockDio();
      notifier = ChatbotNotifier('Test Law', mockDio);
    });

    test('sendMessage calls /api/v1/chat and updates state', () async {
      when(() => mockDio.post('/chat', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/chat'),
                data: {'response': 'This is AI response from server'},
                statusCode: 200,
              ));

      await notifier.sendMessage('Hello AI');

      // State should have: Initial message, User message, AI response
      expect(notifier.state.length, 3);
      expect(notifier.state.last.sender, ChatSender.ai);
      expect(notifier.state.last.text, 'This is AI response from server');

      verify(() => mockDio.post('/chat', data: {
        'message': 'Hello AI',
        'context': 'Test Law',
      })).called(1);
    });

    test('sendMessage handles error and shows error message', () async {
      when(() => mockDio.post('/chat', data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/chat'),
        error: 'Network Error',
      ));

      await notifier.sendMessage('Hello AI');

      expect(notifier.state.last.sender, ChatSender.ai);
      expect(notifier.state.last.text.contains('오류가 발생했습니다'), isTrue);
    });
  });
}
