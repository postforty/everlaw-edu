import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/markdown_quiz_renderer.dart';
import '../../../core/widgets/mastery_celebration_dialog.dart';
import '../providers/incorrect_note_provider.dart';
import '../providers/adaptive_quiz_provider.dart';

class AdaptiveQuizClinicScreen extends ConsumerStatefulWidget {
  final String weakLawRef;

  const AdaptiveQuizClinicScreen({super.key, required this.weakLawRef});

  @override
  ConsumerState<AdaptiveQuizClinicScreen> createState() => _AdaptiveQuizClinicScreenState();
}

class _AdaptiveQuizClinicScreenState extends ConsumerState<AdaptiveQuizClinicScreen> {
  bool _isLoading = true;
  String _simulatedMarkdown = "";
  Map<String, dynamic>? _feedback;

  @override
  void initState() {
    super.initState();
    _simulateQuizGeneration();
  }

  Future<void> _simulateQuizGeneration() async {
    // 실제 API 연동
    final markdown = await ref.read(adaptiveQuizServiceProvider).generateQuiz(widget.weakLawRef);
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
      if (markdown != null) {
        _simulatedMarkdown = markdown;
      } else {
        _simulatedMarkdown = "오류가 발생했습니다. 문제를 생성할 수 없습니다.";
      }
    });
  }

  void _handleSubmit(String answer, String confidence) async {
    final feedbackResponse = await ref.read(adaptiveQuizServiceProvider).submitQuiz(widget.weakLawRef, answer);
    
    if (!mounted) return;
    
    if (feedbackResponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('채점 서버와 통신할 수 없습니다.')));
      return;
    }

    final isCorrect = feedbackResponse['isCorrect'] ?? false;
    setState(() {
      _feedback = feedbackResponse;
    });

    // 비동기로 연속 정답 저장 및 자동 졸업 체크
    final achievedMastery = await ref.read(incorrectNoteProvider.notifier)
        .registerQuizResult(widget.weakLawRef, isCorrect);

    if (isCorrect) {
      // 맞췄을 경우 취약 지수 극복 피드백 제공
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        if (achievedMastery && context.mounted) {
          // 3회 연속 정답 시 졸업 축하 팝업 다이얼로그 호출
          MasteryCelebrationDialog.show(context, widget.weakLawRef);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.school_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('개념 정복 성공! 해당 법령 조항이 오답노트에서 완전히 자동 졸업 처리되었습니다.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 일반 정답 시 피드백 및 연속 정답 상태 안내
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('정답입니다! (해당 조항에 대해 3회 연속 정답 달성 시 자동 졸업)'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
            ),
          );
        }
        
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('취약점 극복 클리닉', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    '이전 오답 이력을 분석하여\n새로운 맞춤형 시나리오 퀴즈를 생성하고 있습니다...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, height: 1.5),
                  ),
                ],
              ),
            )
          : MarkdownQuizRenderer(
              rawMarkdown: _simulatedMarkdown,
              quizFeedback: _feedback,
              onQuizSubmit: _handleSubmit,
            ),
    );
  }
}
