import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/markdown_quiz_renderer.dart';
import '../../chatbot/views/inline_chatbot_sheet.dart';
import '../providers/lesson_provider.dart';

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
