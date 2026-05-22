import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/markdown_quiz_renderer.dart';
import '../providers/incorrect_note_provider.dart';

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
    // 2초 딜레이로 실시간 API 온더플라이 생성 시뮬레이션
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _simulatedMarkdown = '''
### 🎯 AI 맞춤형 취약점 극복 훈련
회원님의 취약 조항인 **${widget.weakLawRef}**에 대하여 완전히 새로운 실무 현장 시나리오의 변형 퀴즈가 생성되었습니다.

### 📝 [QUIZ] ${widget.weakLawRef} 변형 훈련
당신은 신축 건설 현장의 안전 관리자입니다. 고소작업(높이 3.5m)을 진행하던 중 작업자가 안전대를 걸지 않고 작업하는 것을 발견했습니다. 가장 올바른 즉각 조치는 무엇입니까?

1. 작업이 끝날 때까지 기다렸다가 경고한다.
2. 즉시 작업을 중지시키고 안전대 부착 설비에 안전대를 체결하도록 한 뒤 재개시킨다.
3. 작업 속도를 위해 눈감아준다.
4. 구두로만 조심하라고 외치고 지나간다.
''';
    });
  }

  void _handleSubmit(String answer, String confidence) {
    final isCorrect = answer.startsWith('2.');
    setState(() {
      _feedback = {
        'isCorrect': isCorrect,
        'feedback': isCorrect 
            ? '정답입니다! 산업안전보건법에 따라 고소작업 시 추락방지 및 안전대 부착 체결은 필수 조치사항입니다.'
            : '오답입니다. 고소작업 시 추락 위험이 매우 크므로 즉시 작업을 중단하고 안전대 체결 등 안전 조치를 선행해야 합니다.',
        'metaCognitionStatus': isCorrect ? 'safe' : 'danger_unknown',
      };
    });

    if (isCorrect) {
      // 맞췄을 경우 취약 지수 극복 피드백 제공
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 훌륭합니다! 취약 지수가 안전 구역으로 보정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
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
