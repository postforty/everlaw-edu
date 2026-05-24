import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_provider.dart';

// Firebase Cloud Messaging 연동 스키마 캡슐화 (추후 firebase_messaging 패키지 임포트 연동 대응)
class PushNotificationService {
  final Dio _dio;
  
  PushNotificationService(this._dio);

  /// 서비스 초기화
  /// [navigatorKey] GoRouter 또는 Navigator의 글로벌 키를 연결하여 백그라운드 클릭 시 딥링크 자동 리다이렉트
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    debugPrint('🔔 [FCM Service] Initializing Push Notification Service...');
    
    // 1. 알림 권한 획득 (iOS/Android 13+)
    await _requestPermissions();

    // 2. FCM Device Token 조회
    final fcmToken = await _getDeviceToken();
    debugPrint('🔑 [FCM Token] $fcmToken');
    
    // 3. 서버 등록
    if (fcmToken != null) {
      await registerDeviceToken(fcmToken);
    }

    // 4. 백그라운드/종료 상태에서 알림 터치 시 딥링크 라우팅 플로우 구성
    _setupInteraction(navigatorKey);
  }
  
  Future<void> registerDeviceToken(String token) async {
    try {
      await _dio.post(
        '/api/v1/users/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      debugPrint('✅ [FCM Service] Token registered successfully on backend');
    } catch (e) {
      debugPrint('❌ [FCM Service] Failed to register device token: $e');
    }
  }

  /// 임직원 로그인 시, 해당 임직원의 직무군 카테고리를 FCM 토픽으로 구독 처리
  Future<void> subscribeToJobCategoryTopic(String jobCategory) async {
    final sanitizedTopic = jobCategory.replaceAll(' ', '_').toLowerCase();
    debugPrint('📡 [FCM Topic] Subscribing to job category topic: $sanitizedTopic');
    // FirebaseMessaging.instance.subscribeToTopic(sanitizedTopic);
  }

  /// 임직원 로그아웃 시, 직무군 FCM 토픽 구독 해제
  Future<void> unsubscribeFromJobCategoryTopic(String jobCategory) async {
    final sanitizedTopic = jobCategory.replaceAll(' ', '_').toLowerCase();
    debugPrint('📡 [FCM Topic] Unsubscribing from job category topic: $sanitizedTopic');
    // FirebaseMessaging.instance.unsubscribeFromTopic(sanitizedTopic);
  }

  /// 기기 알림 권한 획득
  Future<void> _requestPermissions() async {
    debugPrint('🔔 [FCM Permissions] Requesting system notification permissions...');
    // FirebaseMessaging.instance.requestPermission(...);
  }

  /// FCM 기기 토큰 획득
  Future<String?> _getDeviceToken() async {
    // return await FirebaseMessaging.instance.getToken();
    return "MOCK_FCM_DEVICE_TOKEN_FOR_EVERLAW_EDU";
  }

  /// 알림 인터랙션(탭 시 화면 전환) 설정
  void _setupInteraction(GlobalKey<NavigatorState> navigatorKey) {
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   _handleNotificationClick(message.data, navigatorKey);
    // });
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   debugPrint('🔔 [FCM Foreground] Title: ${message.notification?.title}');
    // });
  }

  /// 알림 데이터(Payload) 클릭 핸들러 - 특정 강좌 ID로 딥링크 라우팅
  void _handleNotificationClick(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('🧭 [FCM Deep-link] Received notification data payload: $data');
    final String? lessonIdStr = data['lessonId'];
    if (lessonIdStr != null) {
      final int? lessonId = int.tryParse(lessonIdStr);
      if (lessonId != null && navigatorKey.currentState != null) {
        debugPrint('🧭 [FCM Deep-link] Navigating directly to Lesson Detail Screen ID: $lessonId');
        navigatorKey.currentState!.pushNamed(
          '/lessons/detail',
          arguments: lessonId,
        );
      }
    }
  }

  /// 강제 모의 알림 수신 에뮬레이터 (개발/통합 테스트용)
  void triggerMockNotification(Map<String, dynamic> mockPayload, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('🧪 [FCM Emulator] Emulating real push notification click payload...');
    _handleNotificationClick(mockPayload, navigatorKey);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final dio = ref.watch(dioProvider);
  return PushNotificationService(dio);
});
