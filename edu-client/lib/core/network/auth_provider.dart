import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
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



  /// 저장된 토큰이 있는지 검증하여 자동 로그인 처리
  Future<bool> checkAutoLogin() async {
    final token = await AuthInterceptor.getToken();
    final refreshToken = await AuthInterceptor.getRefreshToken();

    if (token != null && token.isNotEmpty) {
      if (JwtDecoder.isExpired(token)) {
        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            final response = await _dio.post(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
            );

            if (response.statusCode == 200) {
              final newAccessToken = response.data['token'];
              final newRefreshToken = response.data['refreshToken'];
              final role = response.data['role'];
              final emailStr = response.data['email'];

              if (newAccessToken != null && newRefreshToken != null) {
                await AuthInterceptor.saveToken(newAccessToken);
                await AuthInterceptor.saveRefreshToken(newRefreshToken);
                if (role != null) await AuthInterceptor.saveRole(role);
                
                currentUserRole = role ?? await AuthInterceptor.getRole();
                currentUserEmail = emailStr;
                return true;
              }
            }
          } catch (e) {
            await logout();
            return false;
          }
        }
        await logout();
        return false;
      } else {
        currentUserRole = await AuthInterceptor.getRole();
        return true;
      }
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
        throw Exception('구글 인증 토큰을 가져올 수 없습니다.');
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
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? '서버 통신 중 오류가 발생했습니다.');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('구글 로그인 처리 중 알 수 없는 오류가 발생했습니다.');
    }
    return false;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});
