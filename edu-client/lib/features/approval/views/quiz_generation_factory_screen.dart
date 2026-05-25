import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/approval_provider.dart';
import '../models/source_law.dart';

class QuizGenerationFactoryScreen extends ConsumerWidget {
  const QuizGenerationFactoryScreen({super.key});

  void _generateQuiz(BuildContext context, WidgetRef ref, String lawId, String content) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Set local state to generating
    ref.read(generatingLawsProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.add(lawId);
      return newState;
    });

    try {
      final success = await ref.read(approvalActionNotifierProvider.notifier)
          .triggerGeneration(lawId: lawId, lawContent: content);

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('문제 출제가 요청되었습니다! 잠시 후 승인 대기열에 등록됩니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 3초 단위로 백엔드를 폴링하여(최대 30초) 실제 생성 여부를 체크
        bool isFinished = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 3));
          if (!context.mounted) break;
          
          ref.invalidate(sourceLawsProvider);
          try {
            final currentLaws = await ref.read(sourceLawsProvider.future);
            final targetLaw = currentLaws.firstWhere((l) => l.lawId == lawId, orElse: () => const SourceLaw(lawId: '', lawName: '', article: '', content: ''));
            if (targetLaw.isGenerated) {
              isFinished = true;
              break;
            }
          } catch (_) {}
        }
        
        // Remove from generating state after completion or timeout
        ref.read(generatingLawsProvider.notifier).update((state) {
          final newState = Set<String>.from(state);
          newState.remove(lawId);
          return newState;
        });
      }
    } catch (e) {
      ref.read(generatingLawsProvider.notifier).update((state) {
        final newState = Set<String>.from(state);
        newState.remove(lawId);
        return newState;
      });
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
    final generatingLaws = ref.watch(generatingLawsProvider);

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
              final isGenerating = generatingLaws.contains(law.lawId);
              
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
                          onPressed: isGenerating 
                              ? null 
                              : () {
                                  if (law.isGenerated) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('⚠️ 다시 출제하기', style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: const Text('이미 출제된 법령입니다.\n기존 퀴즈를 덮어쓰고 다시 출제하시겠습니까?\n\n(참고: 기존 데이터는 관리자 승인 완료 시 새로운 퀴즈 내용으로 완전히 대체됩니다.)'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('취소', style: TextStyle(color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _generateQuiz(context, ref, law.lawId, law.content);
                                            },
                                            child: const Text('다시 출제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    _generateQuiz(context, ref, law.lawId, law.content);
                                  }
                                },
                          icon: isGenerating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(law.isGenerated ? Icons.refresh_rounded : Icons.auto_awesome),
                          label: Text(
                            isGenerating ? 'AI 퀴즈 생성 중...' : 
                            (law.isGenerated ? '♻️ 다시 출제하기' : '✨ AI 퀴즈 출제하기')
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: isGenerating ? Colors.grey.shade300 : (law.isGenerated ? Colors.orange.shade50 : null),
                            foregroundColor: isGenerating ? Colors.grey.shade600 : (law.isGenerated ? Colors.deepOrange : null),
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
