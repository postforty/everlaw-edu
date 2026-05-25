import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthInterceptor extends Interceptor {
  // 웹브라우저와 모바일 런타임 간의 하이브리드 스토리지 설정
  static const _secureStorage = FlutterSecureStorage();
  static final Map<String, String> _webStorage = {}; // Web 환경용 폴백 인메모리 스토리지

  /// 보안 토큰 읽기
  static Future<String?> getToken() async {
    if (kIsWeb) {
      return _webStorage['jwt_token'];
    }
    return await _secureStorage.read(key: 'jwt_token');
  }

  /// 보안 토큰 쓰기
  static Future<void> saveToken(String token) async {
    if (kIsWeb) {
      _webStorage['jwt_token'] = token;
    } else {
      await _secureStorage.write(key: 'jwt_token', value: token);
    }
  }

  /// 사용자 역할 읽기
  static Future<String?> getRole() async {
    if (kIsWeb) {
      return _webStorage['user_role'];
    }
    return await _secureStorage.read(key: 'user_role');
  }

  /// 사용자 역할 쓰기
  static Future<void> saveRole(String role) async {
    if (kIsWeb) {
      _webStorage['user_role'] = role;
    } else {
      await _secureStorage.write(key: 'user_role', value: role);
    }
  }

  /// 보안 토큰 파기
  static Future<void> deleteToken() async {
    if (kIsWeb) {
      _webStorage.clear();
    } else {
      await _secureStorage.delete(key: 'jwt_token');
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await getToken();
    
    if (token != null) {
      // HTTP Authorization Bearer 표준 헤더 자동 결합 주입
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 Unauthorized (세션 만료 등) 발생 시 토큰 강제 파기 및 인증 해제 처리
    if (err.response?.statusCode == 401) {
      await deleteToken();
      // TODO: 앱 라우팅 엔진(GoRouter 등)을 통해 로그인 화면으로 리다이렉트 처리 구현 예정
    }
    return super.onError(err, handler);
  }
}
