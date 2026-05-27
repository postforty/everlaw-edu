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

  void _generateSelectedQuizzes(BuildContext context, WidgetRef ref, List<SourceLaw> selectedSourceLaws) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final selectedIds = selectedSourceLaws.map((e) => e.lawId).toSet();

    // Set generating state for all selected
    ref.read(generatingLawsProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.addAll(selectedIds);
      return newState;
    });

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('총 ${selectedIds.length}개 조항에 대해 일괄 출제가 시작되었습니다. 최대 수 분이 소요될 수 있습니다.'),
        backgroundColor: Colors.blueAccent,
      ),
    );

    // 순차적으로 API 호출 및 20초 딜레이 (Rate Limit 우회)
    for (int i = 0; i < selectedSourceLaws.length; i++) {
      final law = selectedSourceLaws[i];
      if (!context.mounted) break;
      
      try {
        await ref.read(approvalActionNotifierProvider.notifier)
            .triggerGeneration(lawId: law.lawId, lawContent: law.content);
        
        // 마지막 항목이 아니면 20초 대기
        if (i < selectedSourceLaws.length - 1) {
          await Future.delayed(const Duration(seconds: 20));
        }
      } catch (e) {
        // 단일 항목 실패 시 무시하고 다음으로 진행
      }
    }

    if (!context.mounted) return;

    // 선택 초기화
    ref.read(selectedLawsProvider.notifier).state = <String>{};

    // 비동기 롱 폴링 (최대 5분 = 10초 x 30회)
    bool allFinished = false;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 10));
      if (!context.mounted) break;

      ref.invalidate(sourceLawsProvider);
      try {
        final currentLaws = await ref.read(sourceLawsProvider.future);
        final stillGenerating = selectedIds.where((id) {
          final targetLaw = currentLaws.firstWhere((l) => l.lawId == id, orElse: () => const SourceLaw(lawId: '', lawName: '', article: '', content: ''));
          return !targetLaw.isGenerated;
        }).toList();

        if (stillGenerating.isEmpty) {
          allFinished = true;
          break;
        }
      } catch (_) {}
    }

    // 상태 정리
    ref.read(generatingLawsProvider.notifier).update((state) {
      final newState = Set<String>.from(state);
      newState.removeAll(selectedIds);
      return newState;
    });

    if (context.mounted && allFinished) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('일괄 출제가 모두 완료되었습니다! 승인 대기열을 확인해주세요.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLawsAsync = ref.watch(sourceLawsProvider);
    final generatingLaws = ref.watch(generatingLawsProvider);
    final selectedLaws = ref.watch(selectedLawsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('문제 출제소', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          sourceLawsAsync.when(
            data: (laws) {
              final availableLaws = laws.where((l) => !l.isGenerated && !generatingLaws.contains(l.lawId)).toList();
              final isAllSelected = availableLaws.isNotEmpty && selectedLaws.length == availableLaws.length;
              return TextButton.icon(
                onPressed: availableLaws.isEmpty ? null : () {
                  if (isAllSelected) {
                    ref.read(selectedLawsProvider.notifier).state = <String>{};
                  } else {
                    ref.read(selectedLawsProvider.notifier).state = availableLaws.map((l) => l.lawId).toSet();
                  }
                },
                icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all, color: availableLaws.isEmpty ? Colors.grey : Colors.blue),
                label: Text(isAllSelected ? '선택 해제' : '전체 선택', style: TextStyle(color: availableLaws.isEmpty ? Colors.grey : Colors.blue)),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          )
        ],
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
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedLaws.contains(law.lawId),
                        onChanged: (law.isGenerated || isGenerating) ? null : (bool? checked) {
                          ref.read(selectedLawsProvider.notifier).update((state) {
                            final newState = Set<String>.from(state);
                            if (checked == true) {
                              newState.add(law.lawId);
                            } else {
                              newState.remove(law.lawId);
                            }
                            return newState;
                          });
                        },
                      ),
                      Expanded(
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
      floatingActionButton: selectedLaws.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final lawsAsync = ref.read(sourceLawsProvider);
                lawsAsync.whenData((laws) {
                  final selectedList = laws.where((l) => selectedLaws.contains(l.lawId)).toList();
                  _generateSelectedQuizzes(context, ref, selectedList);
                });
              },
              icon: const Icon(Icons.bolt),
              label: Text('선택된 ${selectedLaws.length}개 조항 일괄 출제 (총 ${selectedLaws.length * 5}제)'),
              backgroundColor: Colors.blueAccent,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
