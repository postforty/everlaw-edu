import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/quiz_bank_provider.dart';
import '../../../core/widgets/standalone_quiz_card.dart';
import '../../chatbot/views/inline_chatbot_sheet.dart';
import '../../incorrect_note/providers/incorrect_note_provider.dart';
import '../../incorrect_note/models/incorrect_note.dart';
import '../../../core/widgets/mastery_celebration_dialog.dart';

class QuizFeedScreen extends ConsumerStatefulWidget {
  const QuizFeedScreen({super.key});

  @override
  ConsumerState<QuizFeedScreen> createState() => _QuizFeedScreenState();
}

class _QuizFeedScreenState extends ConsumerState<QuizFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _onAnswerSelected(BuildContext context, bool isCorrect, int index, var quizList) {
    final quiz = quizList[index];

    if (isCorrect) {
      // 0.8초 딜레이 후 다음 문제로 자동 전환
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted) return;

        // 마스터리 체크 연동
        final achievedMastery = await ref.read(incorrectNoteProvider.notifier)
            .registerQuizResult(quiz.lawReference, true);

        if (achievedMastery && mounted) {
          MasteryCelebrationDialog.show(context, quiz.lawReference);
        }

        if (mounted && _currentIndex < quizList.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else if (mounted && _currentIndex == quizList.length - 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘의 모의고사를 모두 완료했습니다! 🎉'), backgroundColor: Colors.green),
          );
        }
      });
    } else {
      // 오답 시 오답노트에 즉시 저장
      ref.read(incorrectNoteProvider.notifier).registerQuizResult(quiz.lawReference, false);
      final note = IncorrectNote(
        id: const Uuid().v4(),
        quizId: quiz.id,
        question: quiz.question,
        options: quiz.options,
        answerIndex: quiz.options.indexWhere((o) => o == quiz.correctAnswer),
        selectedIndex: -1, // 추후 StandaloneQuizCard에서 선택된 인덱스 반환 시 연동 가능
        explanation: quiz.explanation,
        lawReference: quiz.lawReference,
        incorrectAt: DateTime.now().toIso8601String(),
      );
      ref.read(incorrectNoteProvider.notifier).addNote(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = ref.watch(quizBankProvider);

    if (quizzes.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('출제된 문제가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 모의고사 피드', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_currentIndex + 1} / ${quizzes.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 스와이프 차단 (정답을 맞춰야만 넘어감)
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemCount: quizzes.length,
        itemBuilder: (context, index) {
          final quiz = quizzes[index];
          return StandaloneQuizCard(
            quiz: quiz,
            onAnswerSelected: (isCorrect) => _onAnswerSelected(context, isCorrect, index, quizzes),
            onChatbotRequested: () {
              final contextMsg = "[오답 질문 문맥]\n- 문제: \${quiz.question}\n- 법적 근거: \${quiz.lawReference}\n- 상세 해설: \${quiz.explanation}\n\n위 내용과 관련하여 상세한 설명을 부탁드립니다.";
              InlineChatbotSheet.show(context, quiz.lawReference, initialContext: contextMsg);
            },
          );
        },
      ),
    );
  }
}
