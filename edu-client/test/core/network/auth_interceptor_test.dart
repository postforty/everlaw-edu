import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:edu_client/core/network/auth_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:edu_client/core/navigation/navigator_key.dart';

class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}
class MockDio extends Mock implements Dio {}
class FakeResponse extends Fake implements Response<dynamic> {}
class FakeDioException extends Fake implements DioException {}

// TDD Phase 2: navigator_key.dart is not yet created in lib, 
// so we will simulate what we expect to test.
// Wait, if I import lib/core/navigation/navigator_key.dart here, it will fail to compile.
// That is exactly what a failing test (Red phase) is!

void main() {
  setUpAll(() {
    registerFallbackValue(FakeResponse());
    registerFallbackValue(FakeDioException());
  });

  late AuthInterceptor interceptor;
  late MockErrorInterceptorHandler mockHandler;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'expired-token',
      'jwt_refresh_token': 'invalid-refresh-token',
    });
    interceptor = AuthInterceptor();
    mockHandler = MockErrorInterceptorHandler();
  });

  group('AuthInterceptor - onError', () {
    testWidgets('리프레시 갱신 실패 시 루트 네비게이터를 통해 리다이렉트를 시도한다', (tester) async {
      // 1. MaterialApp과 rootNavigatorKey를 엮어서 위젯 트리를 구성
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: Text('Home Screen')),
      ));

      // 2. 401 에러 객체 생성
      final requestOptions = RequestOptions(path: '/api/data');
      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
      );

      // 3. onError 호출 (리프레시 실패 상황 시뮬레이션)
      // 내부적으로 Dio().post('/auth/refresh')가 실패하도록 해야 함.
      // 하지만 AuthInterceptor 내부에서 Dio 인스턴스를 새로 생성하므로,
      // 실제 네트워크 요청이 실패(예외 발생)하게 되어 catch 블록으로 빠지거나, 
      // SharedPreferences에 refreshToken이 없어서 바로 로그아웃 처리됨.
      
      // 실행
      interceptor.onError(dioError, mockHandler);

      // 비동기 처리 대기
      await tester.pumpAndSettle();

      // 4. 리다이렉트 확인
      // LoginScreen으로 라우팅 되는지 확인 (현재 LoginScreen이 import 안되어있으므로 형식이 맞는지 정도만)
      // TDD 실패를 보기 위해, 현재 구현에서는 rootNavigatorKey 사용 로직이 없으므로,
      // 화면이 바뀌지 않고 'Home Screen'이 그대로 남아있을 것임.
      expect(find.text('Home Screen'), findsNothing); // 리다이렉트 되었다면 Home Screen이 없어야 함
    });

    test('다중 401 에러 발생 시 리프레시 진행 중이면 요청을 큐에 저장한다', () async {
      final requestOptions1 = RequestOptions(path: '/api/data1');
      final requestOptions2 = RequestOptions(path: '/api/data2');
      
      final dioError1 = DioException(
        requestOptions: requestOptions1,
        response: Response(requestOptions: requestOptions1, statusCode: 401),
      );
      final dioError2 = DioException(
        requestOptions: requestOptions2,
        response: Response(requestOptions: requestOptions2, statusCode: 401),
      );

      final mockHandler2 = MockErrorInterceptorHandler();

      // 첫 번째 401 에러 트리거 (isRefreshing = true 가 됨)
      interceptor.onError(dioError1, mockHandler);

      // 두 번째 401 에러 트리거
      interceptor.onError(dioError2, mockHandler2);

      // 내부적으로 _isRefreshing 플래그로 인해 두 번째 에러는 즉시 반환하고 큐에 담겨야 함
      // (테스트용으로 mockHandler2는 아직 아무것도 호출되지 않아야 함)
      verifyNever(() => mockHandler2.resolve(any()));
      verifyNever(() => mockHandler2.reject(any()));
      verifyNever(() => mockHandler2.next(any()));
    });
  });
}
