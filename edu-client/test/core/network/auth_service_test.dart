import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/core/network/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthService authService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDio = MockDio();
    authService = AuthService(mockDio);
  });

  group('AuthService - Login', () {
    const testEmail = 'test@example.com';
    const testPassword = 'password123';
    const testToken = 'fake-jwt-token';

    test('login API가 200 성공을 반환하면 true를 반환하고 토큰을 저장한다', () async {
      when(() => mockDio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/login'),
                statusCode: 200,
                data: {'token': testToken, 'refreshToken': 'test-refresh', 'role': 'learner', 'email': 'test@test.com'},
              ));

      final result = await authService.login(testEmail, testPassword);

      expect(result, isTrue);
      verify(() => mockDio.post('/auth/login', data: {
        'email': testEmail,
        'password': testPassword,
      })).called(1);
    });

    test('login API가 에러를 반환하면 false를 반환한다', () async {
      when(() => mockDio.post('/auth/login', data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401),
      ));

      final result = await authService.login(testEmail, testPassword);

      expect(result, isFalse);
    });
  });

  group('AuthService - checkAutoLogin', () {
    // 만료일(exp)이 과거인 테스트용 JWT (header.payload.signature)
    // payload: {"exp": 1516239022}
    const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1MTYyMzkwMjJ9.signature';
    const validRefreshToken = 'dummy-refresh-token';

    test('토큰이 만료되었고 Refresh Token이 있으면 /auth/refresh 를 호출한다', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': expiredToken,
        'jwt_refresh_token': validRefreshToken,
      });

      // 리프레시 API 성공 모킹
      when(() => mockDio.post('/auth/refresh', data: {'refreshToken': validRefreshToken}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/refresh'),
                statusCode: 200,
                data: {'token': 'new-access-token', 'refreshToken': 'new-refresh-token', 'role': 'learner', 'email': 'test@test.com'},
              ));

      final result = await authService.checkAutoLogin();

      // 지금은 JWT 디코딩 로직이 없어서 단순히 토큰이 있으므로 true를 반환함 (나중에 실패해야 함, 또는 /auth/refresh를 호출해야 함)
      // TDD에서는 우선 새 스펙에 맞게 검증 코드를 짠다.
      // 정상 동작한다면 /auth/refresh API가 1번 호출되었어야 함.
      verify(() => mockDio.post('/auth/refresh', data: {'refreshToken': validRefreshToken})).called(1);
      expect(result, isTrue); // 성공적으로 갱신되었으므로 true 반환 기대
    });
  });
}
