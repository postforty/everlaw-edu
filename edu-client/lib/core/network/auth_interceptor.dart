import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
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

              // 이전 요청 재시도
              final retryOptions = err.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              
              final retryResponse = await dio.fetch(retryOptions);
              return handler.resolve(retryResponse);
            }
          }
        } catch (e) {
          // 리프레시 토큰 갱신 실패 시
        }
      }

      // 리프레시 실패하거나 토큰이 없는 경우 강제 로그아웃
      await deleteToken();
      // TODO: 앱 라우팅 엔진(GoRouter 등)을 통해 로그인 화면으로 리다이렉트 처리 구현 예정
    }
    return super.onError(err, handler);
  }
}
