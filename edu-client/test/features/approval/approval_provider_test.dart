import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/core/network/dio_provider.dart';
import 'package:edu_client/features/approval/providers/approval_provider.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('Approval Provider Tests', () {
    late MockDio mockDio;
    late ProviderContainer container;

    setUp(() {
      mockDio = MockDio();
      container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('approvalQueueProvider fetches approvals from API', () async {
      when(() => mockDio.get('/approvals', queryParameters: {'status': 'PENDING'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/approvals'),
                data: [
                  {
                    'id': 101,
                    'title': 'Test Approval',
                    'lawReference': 'Law 1',
                    'aiGeneratedMarkdown': 'Markdown',
                    'validationDetails': 'Details',
                    'hallucinationScore': 0.1,
                    'status': 'PENDING',
                    'createdAt': '2026-05-24T00:00:00Z',
                  }
                ],
                statusCode: 200,
              ));

      final queue = await container.read(approvalQueueProvider.future);

      expect(queue.length, 1);
      expect(queue.first.id, 101);
      expect(queue.first.title, 'Test Approval');
      verify(() => mockDio.get('/approvals', queryParameters: {'status': 'PENDING'})).called(1);
    });

    test('ApprovalActionNotifier.processAction posts action to API', () async {
      when(() => mockDio.post('/approvals/101/action', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/approvals/101/action'),
                data: {'success': true},
                statusCode: 200,
              ));

      final notifier = container.read(approvalActionNotifierProvider.notifier);
      final result = await notifier.processAction(
        requestId: 101,
        approved: true,
        adminEmail: 'admin@test.com',
      );

      expect(result, isTrue);
      verify(() => mockDio.post('/approvals/101/action', data: {
        'approved': true,
        'adminEmail': 'admin@test.com',
      })).called(1);
    });

    test('selectedLawsProvider manages selected state correctly', () {
      final selectedLaws = container.read(selectedLawsProvider);
      expect(selectedLaws, isEmpty);

      container.read(selectedLawsProvider.notifier).update((state) {
        final newState = Set<String>.from(state);
        newState.add('law_123');
        return newState;
      });

      final updatedLaws = container.read(selectedLawsProvider);
      expect(updatedLaws.length, 1);
      expect(updatedLaws.contains('law_123'), isTrue);

      container.read(selectedLawsProvider.notifier).update((state) {
        final newState = Set<String>.from(state);
        newState.remove('law_123');
        return newState;
      });

      expect(container.read(selectedLawsProvider), isEmpty);
    });

    test('ApprovalActionNotifier.triggerGeneration posts generation request', () async {
      when(() => mockDio.post('/approvals/generate', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/approvals/generate'),
                data: {'success': true},
                statusCode: 202,
              ));

      final notifier = container.read(approvalActionNotifierProvider.notifier);
      await notifier.triggerGeneration(lawId: 'law_1', lawContent: 'content');

      verify(() => mockDio.post('/approvals/generate', data: {
        'curriculumId': 1,
        'lawId': 'law_1',
        'lawContent': 'content',
      })).called(1);
    });
  });
}
