import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../models/approval_request.dart';
import '../models/source_law.dart';

/// 원본 법령(Source Laws) 목록을 가져오는 FutureProvider
final sourceLawsProvider = FutureProvider.autoDispose<List<SourceLaw>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get('/approvals/source-laws');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => SourceLaw.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    throw Exception('원본 법령 목록 수신 실패: $e');
  }
});

/// 현재 출제 중인 법령 ID 목록을 추적하는 로컬 상태 Provider
final generatingLawsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// 다중 선택된 법령 ID 목록을 추적하는 로컬 상태 Provider (일괄 출제용)
final selectedLawsProvider = StateProvider<Set<String>>((ref) => <String>{});


/// 승인 대기열 리스트(PENDING 상태 필터링)를 실시간 패치하는 FutureProvider (에러 시 Mock 데이터 반환)
final approvalQueueProvider = FutureProvider.autoDispose<List<ApprovalRequest>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    final response = await dio.get(
      '/approvals',
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
        '/approvals/$requestId/action',
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

  /// 새로운 문제 출제 트리거
  Future<bool> triggerGeneration({
    required String lawId,
    required String lawContent,
  }) async {
    state = const AsyncValue.loading();
    final dio = _ref.read(dioProvider);

    try {
      final response = await dio.post(
        '/approvals/generate',
        data: {
          'curriculumId': 1, // Dummy ID for now
          'lawId': lawId,
          'lawContent': lawContent,
        },
      );

      if (response.statusCode == 202) {
        state = const AsyncValue.data(null);
        _ref.invalidate(approvalQueueProvider);
        return true;
      } else {
        throw Exception(response.data['message'] ?? '문제 출제 요청 실패');
      }
    } catch (e) {
      state = const AsyncValue.data(null);
      throw Exception('문제 출제 요청 실패: $e');
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
