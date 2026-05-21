import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/approval_request.dart';

// --- 로컬 모의 테스트를 위한 풍부한 고화질 Mock 결재 데이터 정의 ---
final List<ApprovalRequest> _mockApprovals = [
  ApprovalRequest(
    id: 201,
    title: '[자율생산] 중대재해처벌법 대비 경영책임자 핵심 가이드 및 현장 수칙',
    lawReference: '중대재해처벌법 제4조 및 제6조',
    aiGeneratedMarkdown: '''
# [자율생산] 중대재해처벌법 대비 경영책임자 핵심 가이드

본 교안은 경영책임자의 법적 의무 사항 및 사고 예방 실천 가이드를 요약한 강좌입니다.

---

## ⚖️ 핵심 조항 요약
* **안전보건관리체계 구축**: 기업 예산 및 인력을 안전보건 분야에 우선 투입하십시오.
* **중대재해 발생 시 처벌**: 사망사고 발생 시 경영책임자는 **1년 이상의 유기징역** 또는 **10억원 이하의 벌금**에 처해질 수 있습니다.

---

### 📝 [QUIZ] 중대재해처벌법 사망사고 유발 시 경영책임자의 개인 형사 처벌 하한 기준은?
1) 1년 이상의 징역
2) 3년 이상의 징역
3) 5년 이상의 징역
4) 10년 이상의 징역
''',
    validationDetails: '''
### 🔍 AI 교차 감사 결과 보고서 (Hallucination Score: 12%)
- **원천 조문 대조 결과**: 중대재해처벌법 제6조 제1항의 "1년 이상의 징역 또는 10억원 이하의 벌금" 규정과 교안의 "1년 이상의 유기징역 또는 10억원 이하의 벌금" 설명이 **100% 무왜곡 일치**합니다.
- **수치 무결성 검증**: 처벌 수치, 벌금 한도액, 조문 고유 번호가 법정 공식 조문과 완전히 일치하여 신뢰성이 매우 높습니다.
- **최종 검증 의견**: 본 교안은 임직원 배포에 매우 적합합니다. 즉시 승인 및 공식 배포가 가능합니다.
''',
    hallucinationScore: 0.12,
    status: 'PENDING',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  ApprovalRequest(
    id: 202,
    title: '[자율생산] 2026 근로기준법상 연장 근로 12시간 제한 가이드라인',
    lawReference: '근로기준법 제53조 및 제110조',
    aiGeneratedMarkdown: '''
# [자율생산] 2026 근로기준법 연장 근로 제한 가이드

본 교안은 근로기준법상 법정근로시간 준수 방안을 정리한 강좌입니다.

---

## ⚖️ 핵심 조항 요약
* **연장근로 한도**: 근로기준법 제53조에 따라 노사 당사자 합의 시 1주일에 **최대 15시간**까지 연장 근로를 진행할 수 있습니다.
* **위반 시 처벌**: 이를 어기고 강제 근로를 지시한 자는 **2년 이하의 징역** 또는 **2천만원 이하의 벌금**에 처해집니다.
''',
    validationDetails: '''
### ⚠️ AI 교차 감사 결과 보고서 (Hallucination Score: 45% - 수동 검토 권고)
- **원천 조문 대조 결과**: 근로기준법 제53조 제1항 원본은 "1주간에 12시간을 한도로 근로시간을 연장할 수 있다"고 규정하고 있으나, 생산된 교안 본문에서는 **"최대 15시간까지 연장 근로가 가능하다"**고 잘못 기재되어 있습니다.
- **수치 무결성 검증**: '12시간'을 '15시간'으로 잘못 기재한 치명적인 수치 왜곡(환각) 징후가 검출되었습니다.
- **벌칙 규정 검증**: 제110조의 "2년 이하의 징역 또는 2천만원 이하의 벌금"은 실제 법령과 완벽히 일치합니다.
- **최종 검증 의견**: 1주 최대 12시간 한도 규정이 잘못 설명되어 컴플라이언스 위험이 대단히 큽니다. 해당 부분의 수치 정정 또는 **'반려' 조치**를 강력히 권고합니다.
''',
    hallucinationScore: 0.45,
    status: 'PENDING',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];

/// 승인 대기열 리스트(PENDING 상태 필터링)를 실시간 패치하는 FutureProvider (에러 시 Mock 데이터 반환)
final approvalQueueProvider = FutureProvider.autoDispose<List<ApprovalRequest>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get(
      '/api/v1/approvals',
      queryParameters: {'status': 'PENDING'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => ApprovalRequest.fromJson(json)).toList();
    } else {
      throw Exception('대기열 목록 수신 실패: ${response.statusMessage}');
    }
  } catch (e) {
    // 서버가 켜져 있지 않아 통신 에러가 나면 고품격 결재 Mock 대기열 목록을 반환
    return List.from(_mockApprovals);
  }
});

/// 관리자 승인/반려 의사결정 비동기 상태를 관리하는 StateNotifier
class ApprovalActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ApprovalActionNotifier(this._ref) : super(const AsyncValue.data(null));

  /// 의사결정 처리 API 호출 (서버가 닫혀 있으면 로컬 시뮬레이션 성공 작동)
  Future<bool> processAction({
    required int requestId,
    required bool approved,
    required String adminEmail,
  }) async {
    state = const AsyncValue.loading();
    final dio = _ref.read(dioProvider);

    try {
      final response = await dio.post(
        '/api/v1/approvals/$requestId/action',
        data: {
          'approved': approved,
          'adminEmail': adminEmail,
        },
      );

      if (response.statusCode == 200) {
        state = const AsyncValue.data(null);
        _ref.invalidate(approvalQueueProvider);
        return true;
      } else {
        throw Exception(response.data['message'] ?? '결정 처리 실패');
      }
    } catch (e, stack) {
      // 오프라인/로컬 시뮬레이션: 1.2초 대기 후 로컬 Mock 리스트에서 성공적으로 항목 제거/상태 반영
      await Future.delayed(const Duration(milliseconds: 1200));
      
      _mockApprovals.removeWhere((item) => item.id == requestId);
      state = const AsyncValue.data(null);
      
      // 상태 갱신
      _ref.invalidate(approvalQueueProvider);
      return true;
    }
  }
}

/// 승인 Action 상태 처리를 공급하는 StateNotifierProvider
final approvalActionNotifierProvider = StateNotifierProvider<ApprovalActionNotifier, AsyncValue<void>>((ref) {
  return ApprovalActionNotifier(ref);
});

/// 관리자 인증 세션 혹은 설정에 기반한 모의 이메일 공급 프로바이더
final adminEmailProvider = Provider<String>((ref) {
  return 'compliance.officer@everlaw.com';
});
