import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/quiz_bank_provider.dart';
import '../../../core/widgets/standalone_quiz_card.dart';
import '../../chatbot/views/inline_chatbot_sheet.dart';
import '../../incorrect_note/providers/incorrect_note_provider.dart';
import '../../incorrect_note/models/incorrect_note.dart';
import '../../../core/widgets/mastery_celebration_dialog.dart';
import '../../../core/network/auth_provider.dart';
import '../../auth/views/login_screen.dart';

class QuizFeedScreen extends ConsumerStatefulWidget {
  const QuizFeedScreen({super.key});

  @override
  ConsumerState<QuizFeedScreen> createState() => _QuizFeedScreenState();
}

class _QuizFeedScreenState extends ConsumerState<QuizFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, bool> _answeredMap = {};

  void _onAnswerSelected(BuildContext context, bool isCorrect, int selectedIndex, int index, var quizList) {
    final quiz = quizList[index];

    setState(() {
      _answeredMap[index] = true;
    });

    if (isCorrect) {
      // 0.8초 딜레이 후 다음 문제로 자동 전환
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted) return;

        // 마스터리 체크 연동
        final achievedMastery = await ref.read(incorrectNoteProvider.notifier)
            .submitQuizResult(int.parse(quiz.id), selectedIndex);

        if (achievedMastery && context.mounted) {
          MasteryCelebrationDialog.show(context, quiz.lawReference);
        }

        if (context.mounted && _currentIndex < quizList.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else if (context.mounted && _currentIndex == quizList.length - 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('오늘의 모의고사를 모두 완료했습니다!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } else {
      // 오답 시 오답노트에 즉시 저장
      ref.read(incorrectNoteProvider.notifier).submitQuizResult(int.parse(quiz.id), selectedIndex);
      final note = IncorrectNote(
        id: const Uuid().v4(),
        quizId: quiz.id,
        question: quiz.question,
        options: quiz.options,
        answerIndex: quiz.options.indexWhere((o) => o == quiz.correctAnswer),
        selectedIndex: selectedIndex, 
        explanation: quiz.explanation,
        lawReference: quiz.lawReference,
        incorrectAt: DateTime.now().toIso8601String(),
      );
      ref.read(incorrectNoteProvider.notifier).addNote(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzesAsync = ref.watch(quizBankProvider);

    return quizzesAsync.when(
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('출제된 문제가 없습니다.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('오늘의 모의고사 피드', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${_currentIndex + 1} / ${quizzes.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
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
          body: PageView.builder(
            controller: _pageController,
            physics: _answeredMap[_currentIndex] == true
                ? const BouncingScrollPhysics() // 오답 해설 감상 및 풀이 완료 시 드래그(스와이프) 다음 문제 유연 진입 허용
                : const NeverScrollableScrollPhysics(), // 미풀이 상태에서는 강제 드래그 차단
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return StandaloneQuizCard(
                quiz: quiz,
                onAnswerSelected: (isCorrect, selectedIndex) => _onAnswerSelected(context, isCorrect, selectedIndex, index, quizzes),
                onChatbotRequested: () {
                  final contextMsg = "[오답 질문 문맥]\n- 문제: ${quiz.question}\n- 법적 근거: ${quiz.lawReference}\n- 상세 해설: ${quiz.explanation}\n\n위 내용과 관련하여 상세한 설명을 부탁드립니다.";
                  InlineChatbotSheet.show(context, quiz.lawReference, initialContext: contextMsg);
                },
                onNextPressed: () {
                  if (_currentIndex < quizzes.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('오늘의 모의고사를 모두 완료했습니다!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('오류가 발생했습니다: $error')),
      ),
    );
  }
}
