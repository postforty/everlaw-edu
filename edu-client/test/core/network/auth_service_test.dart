import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/core/network/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthService authService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    mockDio = MockDio();
    authService = AuthService(mockDio);
  });

  group('AuthService - Login', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';
    const testToken = 'fake-jwt-token';

    test('login API가 200 성공을 반환하면 true를 반환하고 토큰을 저장한다', () async {
      when(() => mockDio.post('/api/v1/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/api/v1/auth/login'),
                statusCode: 200,
                data: {'token': testToken},
              ));

      final result = await authService.login(testEmail, testPassword);

      expect(result, isTrue);
      verify(() => mockDio.post('/api/v1/auth/login', data: {
        'email': testEmail,
        'password': testPassword,
      })).called(1);
    });

    test('login API가 에러를 반환하면 false를 반환한다', () async {
      when(() => mockDio.post('/api/v1/auth/login', data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            statusCode: 401),
      ));

      final result = await authService.login(testEmail, testPassword);

      expect(result, isFalse);
    });
  });
}
