import 'dart:convert';
import 'package:flutter/material.dart';

// Firebase Cloud Messaging 연동 스키마 캡슐화 (추후 firebase_messaging 패키지 임포트 연동 대응)
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  /// 서비스 초기화
  /// [navigatorKey] GoRouter 또는 Navigator의 글로벌 키를 연결하여 백그라운드 클릭 시 딥링크 자동 리다이렉트
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    debugPrint('🔔 [FCM Service] Initializing Push Notification Service...');
    
    // 1. 알림 권한 획득 (iOS/Android 13+)
    await _requestPermissions();

    // 2. FCM Device Token 조회 및 서버 등록용 로그 출력
    final fcmToken = await _getDeviceToken();
    debugPrint('🔑 [FCM Token] $fcmToken');

    // 3. 백그라운드/종료 상태에서 알림 터치 시 딥링크 라우팅 플로우 구성
    _setupInteraction(navigatorKey);
  }

  /// 임직원 로그인 시, 해당 임직원의 직무군 카테고리를 FCM 토픽으로 구독 처리
  /// jobCategory: HR, FINANCE, CONSTRUCTION, R_AND_D 등
  Future<void> subscribeToJobCategoryTopic(String jobCategory) async {
    final sanitizedTopic = jobCategory.replaceAll(' ', '_').toLowerCase();
    debugPrint('📡 [FCM Topic] Subscribing to job category topic: $sanitizedTopic');
    
    // FirebaseMessaging.instance.subscribeToTopic(sanitizedTopic);
    // Redis 알림 브로커가 이 토픽으로 발송하면 해당 카테고리 임직원만 선별 수신하게 됩니다.
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

  /// FCM 기기 토큰 획득 (서버 단일 수신용 보관 대응)
  Future<String?> _getDeviceToken() async {
    // return await FirebaseMessaging.instance.getToken();
    return "MOCK_FCM_DEVICE_TOKEN_FOR_EVERLAW_EDU";
  }

  /// 알림 인터랙션(탭 시 화면 전환) 설정
  void _setupInteraction(GlobalKey<NavigatorState> navigatorKey) {
    // 1. 앱이 백그라운드에 있거나 완전히 종료되었을 때, 알림 탭으로 진입할 시 호출
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   _handleNotificationClick(message.data, navigatorKey);
    // });

    // 2. 앱이 실행 중인 포그라운드(Foreground) 상태에서 알림이 도착했을 때 리스너
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   debugPrint('🔔 [FCM Foreground] Title: ${message.notification?.title}');
    // });
  }

  /// 알림 데이터(Payload) 클릭 핸들러 - 특정 강좌 ID로 딥링크 라우팅
  void _handleNotificationClick(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('🧭 [FCM Deep-link] Received notification data payload: $data');
    
    // 백엔드 FCM 페이로드: { "lessonId": "42" }
    final String? lessonIdStr = data['lessonId'];
    if (lessonIdStr != null) {
      final int? lessonId = int.tryParse(lessonIdStr);
      if (lessonId != null && navigatorKey.currentState != null) {
        debugPrint('🧭 [FCM Deep-link] Navigating directly to Lesson Detail Screen ID: $lessonId');
        
        // 피처 내의 LessonDetailScreen으로 즉시 딥링크 강제 이동 처리
        // GoRouter 연동 시: context.push('/lessons/detail/$lessonId');
        // Navigator 글로벌 연동 폴백:
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
