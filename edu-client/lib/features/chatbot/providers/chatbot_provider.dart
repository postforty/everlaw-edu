import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../core/network/dio_provider.dart';

class ChatbotNotifier extends StateNotifier<List<ChatMessage>> {
  final String? _initialLawRef;
  final Dio _dio;

  ChatbotNotifier(this._initialLawRef, this._dio) : super([]) {
    _initializeChat();
  }

  void _initializeChat() {
    final lawContext = _initialLawRef != null ? " '**$_initialLawRef**'" : " 최신 법률";
    state = [
      ChatMessage.ai(
        "안녕하세요! 준법 지원 AI 비서입니다. ⚖️\n현재 학습 중이신$lawContext에 관해 궁금한 실무 해석이나 처벌 조항, 혹은 실제 위반 예방 사례가 있다면 무엇이든 편하게 여쭤보세요!",
        referencedLaw: _initialLawRef,
      ),
    ];
  }

  /// 사용자가 메시지를 전송하고, 실제 서버에서 AI 비서의 응답을 받아옴
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. 유저 메시지 즉시 추가
    final userMsg = ChatMessage.user(text, referencedLaw: _initialLawRef);
    state = [...state, userMsg];

    // 2. 답변 준비 중임을 알리는 임시 타이핑 대답 추가
    final tempAiMsg = ChatMessage(
      sender: ChatSender.ai,
      text: "법률 정보 조회를 위해 실시간 판례 DB 및 팩트를 교차 확인하고 있습니다... 🔍",
      timestamp: DateTime.now(),
      referencedLaw: _initialLawRef,
    );
    state = [...state, tempAiMsg];

    // 3. 실제 API 연동
    try {
      final response = await _dio.post(
        '/api/v1/chat',
        data: {
          'message': text,
          'context': _initialLawRef,
        },
      );

      String responseText = "응답을 파싱할 수 없습니다.";
      if (response.statusCode == 200 && response.data != null) {
        responseText = response.data['response'] as String;
      }

      // 4. 임시 메시지를 실제 대답으로 교체
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage.ai(responseText, referencedLaw: _initialLawRef),
      ];
    } catch (e) {
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage.ai('서버와 통신하는 중 오류가 발생했습니다: $e', referencedLaw: _initialLawRef),
      ];
    }
  }
}

/// 챗 메시지 상태 관리용 StateNotifierProvider.family
final chatbotMessagesProvider = StateNotifierProvider.family.autoDispose<ChatbotNotifier, List<ChatMessage>, String?>((ref, lawRef) {
  final dio = ref.watch(dioProvider);
  return ChatbotNotifier(lawRef, dio);
});
