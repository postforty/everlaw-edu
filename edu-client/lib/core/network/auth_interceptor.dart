import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:edu_client/core/navigation/navigator_key.dart';
import 'package:edu_client/features/auth/views/login_screen.dart';

class AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  final List<Map<String, dynamic>> _failedRequests = [];

  /// 보안 토큰 읽기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// 리프레시 토큰 읽기
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_refresh_token');
  }

  /// 보안 토큰 쓰기
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// 리프레시 토큰 쓰기
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_refresh_token', token);
  }

  /// 사용자 역할 읽기
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  /// 사용자 역할 쓰기
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  /// 보안 토큰 파기
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('jwt_refresh_token');
    await prefs.remove('user_role');
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
    // 401 Unauthorized (세션 만료 등) 발생 시 토큰 갱신 시도
    if (err.response?.statusCode == 401) {
      // 무한 루프 방지를 위해 refresh 요청 자체에서 발생한 401은 바로 파기
      if (err.requestOptions.path.contains('/auth/refresh')) {
        await deleteToken();
        return super.onError(err, handler);
      }

      if (_isRefreshing) {
        // 이미 갱신 중이라면 큐에 담아 대기
        _failedRequests.add({'err': err, 'handler': handler});
        return;
      }

      _isRefreshing = true;

      final refreshToken = await getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final dio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
          final refreshResponse = await dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          if (refreshResponse.statusCode == 200) {
            final newAccessToken = refreshResponse.data['token'];
            final newRefreshToken = refreshResponse.data['refreshToken'];

            if (newAccessToken != null && newRefreshToken != null) {
              await saveToken(newAccessToken);
              await saveRefreshToken(newRefreshToken);

              // 현재 실패한 원래 요청 재시도
              final retryOptions = err.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              
              try {
                final retryResponse = await dio.fetch(retryOptions);
                handler.resolve(retryResponse);
              } catch(e) {
                handler.reject(err);
              }

              // 큐에 쌓인 나머지 요청들도 일괄 재시도
              for (var request in _failedRequests) {
                final failedErr = request['err'] as DioException;
                final failedHandler = request['handler'] as ErrorInterceptorHandler;
                
                final retryFailedOptions = failedErr.requestOptions;
                retryFailedOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                
                try {
                  final response = await dio.fetch(retryFailedOptions);
                  failedHandler.resolve(response);
                } catch (e) {
                  failedHandler.reject(failedErr);
                }
              }
              _failedRequests.clear();
              _isRefreshing = false;
              return;
            }
          }
        } catch (e) {
          // 리프레시 토큰 갱신 실패 시
        }
      }

      // 리프레시 실패하거나 토큰이 없는 경우 강제 로그아웃
      _failedRequests.clear();
      _isRefreshing = false;
      await deleteToken();
      
      // 앱 라우팅 엔진(전역 네비게이터)을 통해 로그인 화면으로 즉시 리다이렉트
      if (rootNavigatorKey.currentState != null) {
        rootNavigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
    return super.onError(err, handler);
  }
}
