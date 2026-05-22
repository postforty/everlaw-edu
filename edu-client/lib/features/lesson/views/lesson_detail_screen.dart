import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/markdown_quiz_renderer.dart';
import '../../chatbot/views/inline_chatbot_sheet.dart';
import '../providers/lesson_provider.dart';
import '../../incorrect_note/providers/incorrect_note_provider.dart';
import '../../incorrect_note/models/incorrect_note.dart';
import '../../../core/widgets/mastery_celebration_dialog.dart';
import 'package:uuid/uuid.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const LessonDetailScreen({
    super.key,
    required this.lessonId,
  });

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 재진입 시 기존 퀴즈 풀이 상태 초기화
    Future.microtask(() {
      ref.read(quizSubmissionNotifierProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final quizState = ref.watch(quizSubmissionNotifierProvider);
    final theme = Theme.of(context);

    final isSubmitting = quizState is AsyncLoading;
    final Map<String, dynamic>? feedback = quizState.when(
      data: (data) => data,
      error: (_, __) => null,
      loading: () => null,
    );

    ref.listen(quizSubmissionNotifierProvider, (previous, next) {
      if (next is AsyncData && next.value != null && previous?.value == null) {
        final data = next.value!;
        final isCorrect = data['isCorrect'] as bool? ?? false;
        final lesson = lessonAsync.valueOrNull;
        if (lesson == null) return;

        if (isCorrect) {
          // [U-3] 0.8s motion delay and mastery check
          Future.delayed(const Duration(milliseconds: 800), () async {
            if (!mounted) return;
            final achievedMastery = await ref.read(incorrectNoteProvider.notifier)
                .registerQuizResult(lesson.associatedLawReference, true);
            
            if (achievedMastery && mounted) {
              // [U-8] 지능형 자동 졸업 축하 위젯 호출
              MasteryCelebrationDialog.show(context, lesson.associatedLawReference);
            } else if (mounted) {
              // 일반 정답 처리 (다음 상태 갱신 - 여기서는 이전 화면 복귀 혹은 완료 토스트)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('정답입니다! 퀴즈가 완료되었습니다.'), backgroundColor: Colors.green),
              );
            }
          });
        } else {
          // 오답 시 IncorrectNote 저장 연동
          ref.read(incorrectNoteProvider.notifier).registerQuizResult(lesson.associatedLawReference, false);
          
          // 임시 추출 (실제로는 정규식 등으로 question, options 추출)
          final note = IncorrectNote(
            id: const Uuid().v4(),
            quizId: lesson.id.toString(),
            question: '틀린 문제 자동 추출 (임시)',
            options: const ['A', 'B', 'C', 'D'],
            answerIndex: 0,
            selectedIndex: -1, // 추후 MarkdownQuizRenderer 상태 연동 필요 시 보강
            explanation: data['feedback'] ?? '',
            lawReference: lesson.associatedLawReference,
            incorrectAt: DateTime.now().toIso8601String(),
          );
          ref.read(incorrectNoteProvider.notifier).addNote(note);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '실시간 강좌 학습실',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          // 1. 실시간 법률 자문 AI 챗봇 호출 버튼
          lessonAsync.when(
            data: (lesson) => IconButton(
              icon: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary, size: 26),
              onPressed: () {
                InlineChatbotSheet.show(context, lesson.associatedLawReference);
              },
              tooltip: 'AI 법률 자문 비서',
            ),
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          
          if (feedback != null) 
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.read(quizSubmissionNotifierProvider.notifier).reset();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('퀴즈 풀이가 초기화되었습니다. 다시 풀 수 있습니다.')),
                );
              },
              tooltip: '퀴즈 다시 풀기',
            ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: Colors.white,
      body: lessonAsync.when(
        data: (lesson) {
          return Column(
            children: [
              // 강좌 상단 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: theme.colorScheme.primary.withOpacity(0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lesson.curriculum.category,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '근거 규정: ${lesson.associatedLawReference}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lesson.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 22,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (lesson.isRecentlyRevised)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade100.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.amber.shade900, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚖️ 실시간 개정 및 퀴즈 갱신 완료 (Revision ${lesson.revisionNumber})',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '산업안전보건법이 최근 개정되어 본문 수치와 모의 평가 퀴즈가 자동으로 실시간 최신화되었습니다. 개정된 내용을 파악하고 새로운 퀴즈를 통하여 당신의 메타인지를 점검해 보세요!',
                              style: TextStyle(
                                color: Color(0xFF451A03),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 마크다운 & 퀴즈 스크롤 영역
              Expanded(
                child: MarkdownQuizRenderer(
                  rawMarkdown: lesson.contentMarkdown,
                  isSubmitting: isSubmitting,
                  quizFeedback: feedback,
                  onChatbotRequested: feedback != null && !(feedback['isCorrect'] as bool? ?? false)
                      ? () {
                          final contextMsg = "[오답 질문 문맥]\n- 법적 근거: ${lesson.associatedLawReference}\n- 상세 해설: ${feedback['feedback']}\n\n위 내용과 관련하여 추가적인 설명을 부탁드립니다.";
                          InlineChatbotSheet.show(context, lesson.associatedLawReference, initialContext: contextMsg);
                        }
                      : null,
                  onQuizSubmit: (selectedAnswer, confidenceLevel) {
                    // 번호 형태로 백엔드에 제출하기 위해 포맷 가공 파싱 처리
                    final int dotIndex = selectedAnswer.indexOf('.');
                    String answerPayload = selectedAnswer;
                    if (dotIndex != -1) {
                      answerPayload = selectedAnswer.substring(0, dotIndex).trim();
                    }
                    
                    ref.read(quizSubmissionNotifierProvider.notifier).submitAnswer(
                      widget.lessonId,
                      answerPayload,
                      confidenceLevel,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('강좌 본문 및 평가 자료 구성 중...'),
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
                  '강의실 입장 중 문제가 발생하였습니다.',
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
                  onPressed: () => ref.invalidate(lessonDetailProvider(widget.lessonId)),
                  child: const Text('강의실 재접속'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
