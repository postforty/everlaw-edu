import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/incorrect_note_provider.dart';
import '../../chatbot/views/inline_chatbot_sheet.dart';
import 'adaptive_quiz_clinic_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/auth_provider.dart';
import '../../auth/views/login_screen.dart';
class IncorrectNoteScreen extends ConsumerWidget {
  const IncorrectNoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(incorrectNoteProvider).where((n) => !n.isArchived).toList();
    final theme = Theme.of(context);

    // 가장 많이 틀린 법령 조항 추출 (간단한 로직)
    String? topWeaknessLawRef;
    if (notes.isNotEmpty) {
      final counts = <String, int>{};
      for (var note in notes) {
        counts[note.lawReference] = (counts[note.lawReference] ?? 0) + 1;
      }
      topWeaknessLawRef = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 오답노트', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            tooltip: '로그아웃',
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Text('아직 저장된 오답이 없습니다.\n학습을 통해 지식을 넓혀보세요!', textAlign: TextAlign.center),
            )
          : Column(
              children: [
                // [U-6] 진입점 배너
                if (topWeaknessLawRef != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology_rounded, color: Colors.white, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '지능형 취약점 극복 훈련',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '취약 조항: $topWeaknessLawRef',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdaptiveQuizClinicScreen(weakLawRef: topWeaknessLawRef!)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: theme.colorScheme.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('훈련 시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // 오답 리스트
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final dateStr = note.incorrectAt.isNotEmpty 
                          ? DateFormat('yyyy.MM.dd HH:mm').format(DateTime.tryParse(note.incorrectAt) ?? DateTime.now())
                          : '';

                      return Dismissible(
                        key: Key(note.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 30),
                        ),
                        onDismissed: (direction) {
                          ref.read(incorrectNoteProvider.notifier).deleteNote(note.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('해당 오답 항목을 학습 완료(삭제) 처리했습니다.')),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.premiumSoft,
                        ),
                        child: Material(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Theme(
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                                title: Text(
                                  note.lawReference,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    dateStr,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  // 질문 영역
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Q. ${note.question}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.4),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // 보기 영역
                                  ...List.generate(note.options.length, (optIdx) {
                                    final optionStr = note.options[optIdx];
                                    final isCorrect = optIdx == note.answerIndex;
                                    final isSelectedWrong = optIdx == note.selectedIndex && !isCorrect;
                                    
                                    Color bgColor = Colors.transparent;
                                    Color textColor = Colors.grey.shade800;
                                    FontWeight fw = FontWeight.normal;
                                    
                                    if (isCorrect) {
                                      bgColor = Colors.green.shade50;
                                      textColor = Colors.green.shade800;
                                      fw = FontWeight.bold;
                                    } else if (isSelectedWrong) {
                                      bgColor = Colors.red.shade50;
                                      textColor = Colors.red.shade800;
                                      fw = FontWeight.w600;
                                    }

                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isCorrect ? Colors.green.shade200 : (isSelectedWrong ? Colors.red.shade200 : Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        optionStr,
                                        style: TextStyle(color: textColor, fontWeight: fw, fontSize: 13.5),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  // 해설 영역
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.lightbulb_outline_rounded, size: 18, color: theme.colorScheme.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              '상세 해설',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          note.explanation,
                                          style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          final contextMsg = "[오답 복습 문맥]\n- 법적 근거: ${note.lawReference}\n- 해설: ${note.explanation}\n\n이 부분에 대해 다시 설명해 주시겠어요?";
                                          InlineChatbotSheet.show(context, note.lawReference, initialContext: contextMsg);
                                        },
                                        icon: const Icon(Icons.smart_toy_rounded, size: 18),
                                        label: const Text('AI 질문하기'),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          // [U-7] 학습 완료(삭제)
                                          ref.read(incorrectNoteProvider.notifier).deleteNote(note.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('해당 오답 항목을 학습 완료(삭제) 처리했습니다.')),
                                          );
                                        },
                                        icon: Icon(Icons.remove_circle_outline_rounded, color: theme.colorScheme.primary, size: 22),
                                        tooltip: '학습 완료 및 오답 제거',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
