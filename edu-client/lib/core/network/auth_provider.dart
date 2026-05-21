import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_provider.dart';
import 'auth_interceptor.dart';

enum DemoRole {
  learner,
  admin,
}

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  /// 역할에 따른 데모 자동 로그인/회원가입 처리
  Future<bool> authenticateDemoUser(DemoRole role) async {
    final String email = role == DemoRole.learner ? 'learner@everlaw.edu' : 'admin@everlaw.edu';
    const String password = 'password123!';
    final String apiRole = role == DemoRole.learner ? 'LEARNER' : 'ADMIN';
    final String jobCategory = role == DemoRole.learner ? '생산·안전 경영책임자' : 'ADMIN';

    try {
      // 1단계: 로그인 시도
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'] as String;
        await AuthInterceptor.saveToken(token);
        return true;
      }
    } on DioException catch (e) {
      // 400 Bad Request 또는 403 Forbidden 등으로 로그인이 실패했거나 계정이 존재하지 않는 경우 회원가입 시도
      if (e.response != null && (e.response!.statusCode == 400 || e.response!.statusCode == 403 || e.response!.statusCode == 401 || e.response!.statusCode == 500)) {
        try {
          final signUpResponse = await _dio.post(
            '/api/v1/auth/signup',
            data: {
              'email': email,
              'password': password,
              'role': apiRole,
              'jobCategory': jobCategory,
            },
          );

          if (signUpResponse.statusCode == 201 || signUpResponse.statusCode == 200) {
            final token = signUpResponse.data['token'] as String;
            await AuthInterceptor.saveToken(token);
            return true;
          }
        } catch (signUpError) {
          // 회원가입마저 에러가 난 경우 (예: 다른 원인의 서버 에러)
          return false;
        }
      }
      // 서버가 꺼져 있거나 타임아웃인 경우 등
      return false;
    } catch (e) {
      return false;
    }
    return false;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});
