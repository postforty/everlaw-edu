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
  String? currentUserRole;
  String? currentUserEmail;

  AuthService(this._dio);

  /// 이메일/비밀번호 기반 실제 로그인
  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'] as String;
        final role = response.data['role'] as String;
        final emailStr = response.data['email'] as String;
        await AuthInterceptor.saveToken(token);
        await AuthInterceptor.saveRole(role);
        currentUserRole = role;
        currentUserEmail = emailStr;
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// 이메일/비밀번호 기반 회원가입
  Future<bool> signup({
    required String email,
    required String password,
    required String role,
    required String jobCategory,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'role': role,
          'jobCategory': jobCategory,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = response.data['token'] as String;
        final userRole = response.data['role'] as String;
        final emailStr = response.data['email'] as String;
        await AuthInterceptor.saveToken(token);
        await AuthInterceptor.saveRole(userRole);
        currentUserRole = userRole;
        currentUserEmail = emailStr;
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// 저장된 토큰이 있는지 검증하여 자동 로그인 처리
  Future<bool> checkAutoLogin() async {
    final token = await AuthInterceptor.getToken();
    if (token != null && token.isNotEmpty) {
      currentUserRole = await AuthInterceptor.getRole();
      return true;
    }
    return false;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});
