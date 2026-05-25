import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/approval_request.dart';
import '../providers/approval_provider.dart';
import 'approval_detail_screen.dart';
import '../../../core/network/dio_provider.dart';

class ApprovalQueueScreen extends ConsumerWidget {
  const ApprovalQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(approvalQueueProvider);
    final theme = Theme.of(context);
    final dio = ref.watch(dioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '컴플라이언스 자율 생산 검토 대기열',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(approvalQueueProvider),
            tooltip: '새로고침',
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI 엔진에 퀴즈 생성을 요청했습니다... (잠시 후 새로고침 해주세요)')),
              );
              await dio.post(
                '/approvals/generate',
                data: {
                  'curriculumId': 1, // 테스트용 ID
                  'lawId': '산업안전보건법 제38조',
                  'lawContent': '사업주는 근로자가 추락할 위험이 있는 장소, 토사·구축물 등이 붕괴할 우려가 있는 장소 등에서 작업할 때에 추락 방지망을 설치해야 한다.',
                },
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('생성 요청 실패: $e')),
              );
            }
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('수동 생성 트리거'),
        ),
      ),
      body: queueAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule_folder_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '검토할 승인 대기열이 비어 있습니다.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI 엔진이 개정 법령 데이터를 감시 및 신규 퀴즈를 생산하고 있습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // 화면 폭에 따른 모바일/웹 레이아웃 대응 분기
          final width = MediaQuery.of(context).size.width;
          final isWeb = width >= 800;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '검토 대기 항목: 총 ${requests.length}건',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'AI Agent 감시 작동 중',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isWeb
                      ? GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            return _buildQueueCard(context, request, theme);
                          },
                        )
                      : ListView.builder(
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildQueueCard(context, request, theme),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('실시간 승인 대기열 적재 목록 로딩 중...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(
                  '대기열 로드 중 에러가 발생하였습니다.',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(approvalQueueProvider),
                  child: const Text('다시 시도하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueCard(BuildContext context, ApprovalRequest request, ThemeData theme) {
    final score = request.hallucinationScore;
    final isSafe = score <= 0.3;
    final scoreColor = isSafe 
        ? Colors.green.shade600 
        : score < 0.7 
            ? Colors.orange.shade700 
            : Colors.red.shade700;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApprovalDetailScreen(request: request),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '근거: ${request.lawReference}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.query_stats_rounded, color: scoreColor, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '환각지수: ${(score * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                request.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '생성일자: ${request.createdAt.toString().substring(0, 16)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Row(
                    children: [
                      Text(
                        '상세 대조 감사하기',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
