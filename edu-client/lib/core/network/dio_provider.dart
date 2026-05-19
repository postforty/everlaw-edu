import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080', // Spring Boot 백엔드 기본 서버 포트
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  
  // JWT 인증 토큰 자동 삽입 인터셉터 연동
  dio.interceptors.add(AuthInterceptor());
  
  // 디버그 로깅 인터셉터 추가 (개발 단계 트래킹)
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});
