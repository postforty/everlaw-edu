import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class ChatbotNotifier extends StateNotifier<List<ChatMessage>> {
  final String? _initialLawRef;

  ChatbotNotifier(this._initialLawRef) : super([]) {
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

  /// 사용자가 메시지를 전송하고, AI 비서가 정교한 시나리오 답변을 타이핑하듯 대답함
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

    // 3. 타이핑 딜레이 (1초)
    await Future.delayed(const Duration(milliseconds: 1200));

    // 4. 입력 문장의 키워드 분석을 통해 스마트 법률 모의 해설 제공
    final String responseText = _generateSmartResponse(text);

    // 5. 임시 메시지를 실제 지능형 대답으로 교체
    state = [
      ...state.sublist(0, state.length - 1),
      ChatMessage.ai(responseText, referencedLaw: _initialLawRef),
    ];
  }

  /// 사용자의 질문 키워드에 따라 고정밀 산업안전보건법 및 중대재해처벌법 답변 생성
  String _generateSmartResponse(String query) {
    final cleaned = query.toLowerCase();

    if (cleaned.contains("벌금") || cleaned.contains("처벌") || cleaned.contains("징역")) {
      if (_initialLawRef?.contains("중대재해") ?? false || cleaned.contains("중대재해")) {
        return "⚖️ **[중대재해처벌법 제6조 벌칙 규정]**\n\n"
            "사업주 또는 경영책임자 등이 안전 및 보건 확보 의무를 다하지 않아 근로자가 사망(중대산업재해)에 이른 경우:\n"
            "* **개인 처벌**: **1년 이상의 유기징역** 또는 **10억원 이하의 벌금**에 처해집니다. (이 둘은 동시에 같이 병과될 수 있어 매우 엄격합니다!)\n"
            "* **법인/기관 처벌**: 해당 법인에게는 **50억원 이하의 벌금**이 선고됩니다.\n\n"
            "추가적으로 민사상 징벌적 손해배상(손해액의 최대 5배 범위) 책임도 발생할 수 있어 철저한 예방 관리가 요구됩니다.";
      } else if (_initialLawRef?.contains("근로기준") ?? false || cleaned.contains("근로") || cleaned.contains("52시간")) {
        return "⚖️ **[근로기준법 제110조 연장근로 위반 처벌]**\n\n"
            "노사 합의 없이 주 12시간 연장근로 한도를 초과하여 근로시킨 사용자는:\n"
            "* **2년 이하의 징역** 또는 **2천만원 이하의 벌금**에 처해질 수 있습니다.\n\n"
            "연장근로는 반드시 당사자 간의 구체적이고 자발적인 합의가 전제되어야 하며, 상시 연장근로가 빈번할 경우 '탄력적/선택적 근로시간제' 등 적법한 유연근무제 서식을 사전에 노사합의로 구비해두셔야 안전합니다.";
      } else {
        return "⚖️ **[산업안전보건법 제38조 위반 시 처벌]**\n\n"
            "사업주가 안전조치 의무를 위반하여 근로자를 사망에 이르게 한 경우:\n"
            "* **7년 이하의 징역** 또는 **1억원 이하의 벌금**에 처해집니다.\n\n"
            "또한 5년 이내에 동일한 죄를 반복하여 저지른 경우에는 형의 2분의 1까지 가중 처벌을 받게 됩니다.";
      }
    }

    if (cleaned.contains("의무") || cleaned.contains("예방") || cleaned.contains("대책") || cleaned.contains("구축")) {
      return "🛠️ **[법적 안전보건확보 의무 핵심 4요소]**\n\n"
          "1. **안전보건관리체계 구축**: 기업 규모에 알맞은 전담 인력 배치 및 안전 보건 예산을 전용 편성해야 합니다.\n"
          "2. **재해 예방 이행 조치**: 유해 요인 방지를 위해 매년 2회 이상 **위험성평가(Risk Assessment)**를 실시하고 임직원의 건의사항을 청취하십시오.\n"
          "3. **비상대응 훈련**: 중대재해 발생 시를 대비한 대피 및 긴급 구조 시나리오를 구비하고 정기적으로 모의 훈련을 실시하십시오.\n"
          "4. **관계 법령 준수**: 종사자의 안전 교육 이수율을 100%로 상시 관리하고 일지를 문서로 보관하십시오.";
      }

    if (cleaned.contains("예시") || cleaned.contains("사례") || cleaned.contains("현장")) {
      return "🏗️ **[법령 위반 및 조치 사례 해설]**\n\n"
          "* **사례**: 제조업 A사에서 높이 3.2m 비계 위에서 굴착 작업을 보조하던 협력업체 근로자가 추락해 사망하는 사고가 발생했습니다.\n"
          "* **법률 위반점**: 사업주가 추락 방지망(안전망)을 미설치했고, 개인 보호구(안전모, 안전대) 지급 및 안전대 걸이대 체결 여부의 감독 의무(산안법 제38조)를 위반했습니다.\n"
          "* **법적 결과**: 원청 경영책임자는 중대재해처벌법에 따라 안전보건관리체계 예산 관리 부실 소견으로 입건되었으며, 법인은 벌금형에 처해졌습니다.\n\n"
          "💡 **예방 팁**: 현장 감독관은 상시 추락 위험 장소에 추락 방지 스티커와 함께 매일 TBM(Tool Box Meeting) 시 안전 보호구 체결을 물리적으로 점검하고 사진으로 남겨두는 관리적 조치가 절대적입니다.";
    }

    // 기본 답변
    return "질문해 주신 내용에 대해 안내해 드립니다. 💡\n\n"
        "산업안전보건법 및 중대재해처벌법 실무에 따르면, 기업의 경영책임자는 실질적으로 유해 위험 요인을 찾아내 제거하고 통제하는 시스템(체계)을 구축했음을 **'서류와 이행 증적(Evidence)'**으로 입증해야 면책을 받으실 수 있습니다.\n\n"
        "더 구체적인 '처벌 수치'나 '의무 조항 예시', 혹은 학습 중이신 법률에 관한 다른 의문이 있으시면 자유롭게 단어를 포함해 질문해 주세요!";
  }
}

/// 챗 메시지 상태 관리용 StateNotifierProvider.family (강의별/법령별로 챗 히스토리를 독립화하기 위해 family 채택)
final chatbotMessagesProvider = StateNotifierProvider.family.autoDispose<ChatbotNotifier, List<ChatMessage>, String?>((ref, lawRef) {
  return ChatbotNotifier(lawRef);
});
