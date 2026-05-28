import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api/v1';
  
  if (!kIsWeb && Platform.isAndroid) {
    baseUrl = baseUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
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
