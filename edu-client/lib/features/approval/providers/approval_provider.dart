import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/approval_request.dart';


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
      if (data.isEmpty) {
        return [];
      }
      return data.map((json) => ApprovalRequest.fromJson(json)).toList();
    } else {
      throw Exception('대기열 목록 수신 실패: ${response.statusMessage}');
    }
  } catch (e) {
    throw Exception('대기열 목록 수신 실패: $e');
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
    } catch (e) {
      state = const AsyncValue.data(null);
      throw Exception('의사결정 처리 실패: $e');
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
