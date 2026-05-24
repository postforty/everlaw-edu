import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/core/services/push_notification_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('PushNotificationService Test', () {
    late MockDio mockDio;
    late PushNotificationService service;

    setUp(() {
      mockDio = MockDio();
      service = PushNotificationService(mockDio);
    });

    test('registerDeviceToken sends POST request to backend', () async {
      when(() => mockDio.post('/api/v1/users/device-token', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/users/device-token'),
                data: {'success': true},
                statusCode: 200,
              ));

      await service.registerDeviceToken('my-fcm-token');

      verify(() => mockDio.post('/api/v1/users/device-token', data: {
        'token': 'my-fcm-token',
        'platform': 'android', // or ios
      })).called(1);
    });
  });
}
