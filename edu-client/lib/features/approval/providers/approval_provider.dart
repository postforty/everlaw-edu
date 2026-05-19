import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/approval_request.dart';

/// 승인 대기열 리스트(PENDING 상태 필터링)를 실시간 패치하는 FutureProvider
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
    throw Exception('API 통신 에러로 승인 대기열을 불러올 수 없습니다: $e');
  }
});

/// 관리자 승인/반려 의사결정 비동기 상태를 관리하는 StateNotifier
class ApprovalActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ApprovalActionNotifier(this._ref) : super(const AsyncValue.data(null));

  /// 의사결정 처리 API 호출
  /// approved: true (승인) / false (반려)
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
        // 처리 완료 후 승인 대기열 캐시 갱신(refresh)
        _ref.invalidate(approvalQueueProvider);
        return true;
      } else {
        throw Exception(response.data['message'] ?? '결정 처리 실패');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// 승인 Action 상태 처리를 공급하는 StateNotifierProvider
final approvalActionNotifierProvider = StateNotifierProvider<ApprovalActionNotifier, AsyncValue<void>>((ref) {
  return ApprovalActionNotifier(ref);
});
