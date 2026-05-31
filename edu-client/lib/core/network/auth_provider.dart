import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
        final refreshToken = response.data['refreshToken'] as String;
        final role = response.data['role'] as String;
        final emailStr = response.data['email'] as String;
        await AuthInterceptor.saveToken(token);
        await AuthInterceptor.saveRefreshToken(refreshToken);
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
        final refreshToken = response.data['refreshToken'] as String;
        final userRole = response.data['role'] as String;
        final emailStr = response.data['email'] as String;
        await AuthInterceptor.saveToken(token);
        await AuthInterceptor.saveRefreshToken(refreshToken);
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
  /// 로그아웃 처리
  Future<bool> logout() async {
    await AuthInterceptor.deleteToken();
    currentUserRole = null;
    currentUserEmail = null;
    return true;
  }

  /// 구글 소셜 로그인 처리
  Future<bool> googleLogin() async {
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: clientId,
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // 사용자가 로그인 팝업을 취소한 경우
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        return false;
      }

      // 서버의 구글 로그인 API 호출
      final response = await _dio.post(
        '/auth/google',
        data: {
          'idToken': idToken,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'] as String;
        final refreshToken = response.data['refreshToken'] as String;
        final role = response.data['role'] as String;
        final emailStr = response.data['email'] as String;
        await AuthInterceptor.saveToken(token);
        await AuthInterceptor.saveRefreshToken(refreshToken);
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
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});
