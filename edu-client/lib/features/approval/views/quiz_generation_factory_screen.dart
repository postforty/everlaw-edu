import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/approval_provider.dart';

class QuizGenerationFactoryScreen extends ConsumerWidget {
  const QuizGenerationFactoryScreen({super.key});

  void _generateQuiz(BuildContext context, WidgetRef ref, String lawId, String content) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ref.read(approvalActionNotifierProvider.notifier)
          .triggerGeneration(lawId: lawId, lawContent: content);

      // Close loading indicator
      if (context.mounted) Navigator.of(context).pop();

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('문제 출제가 요청되었습니다! 승인 대기열에 등록됩니다.'),
            backgroundColor: Colors.green,
          ),
        );
        // Go back to approval queue
        if (context.mounted) navigator.pop();
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) Navigator.of(context).pop();
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('문제 출제 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLawsAsync = ref.watch(sourceLawsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('문제 출제소', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: sourceLawsAsync.when(
        data: (laws) {
          if (laws.isEmpty) {
            return const Center(child: Text('출제 가능한 원본 법령이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: laws.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final law = laws[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gavel_rounded, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              law.lawId,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        law.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => _generateQuiz(context, ref, law.lawId, law.content),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI 퀴즈 출제하기'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류가 발생했습니다: $error')),
      ),
    );
  }
}
