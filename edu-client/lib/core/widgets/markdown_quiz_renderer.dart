import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownQuizRenderer extends StatefulWidget {
  final String rawMarkdown;
  final Function(String selectedAnswer, String confidenceLevel) onQuizSubmit;
  final bool isSubmitting;
  final Map<String, dynamic>? quizFeedback; // { "correct": bool, "explanation": String, "metaCognitionStatus": String }

  const MarkdownQuizRenderer({
    super.key,
    required this.rawMarkdown,
    required this.onQuizSubmit,
    this.isSubmitting = false,
    this.quizFeedback,
  });

  @override
  State<MarkdownQuizRenderer> createState() => _MarkdownQuizRendererState();
}

class _MarkdownQuizRendererState extends State<MarkdownQuizRenderer> {
  String? _selectedOption;
  String? _selectedConfidence; // 'CONFIDENT', 'UNSURE', 'GUESSED'
  String _bodyMarkdown = "";
  String _quizQuestion = "";
  List<String> _quizOptions = [];

  @override
  void initState() {
    super.initState();
    _parseMarkdownAndQuiz();
  }

  @override
  void didUpdateWidget(covariant MarkdownQuizRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawMarkdown != widget.rawMarkdown) {
      _parseMarkdownAndQuiz();
    }
    // 피드백이 리셋되거나 새로 들어오면 선택 상태 동기화 처리
    if (widget.quizFeedback == null && oldWidget.quizFeedback != null) {
      _selectedOption = null;
      _selectedConfidence = null;
    }
  }

  /// 마크다운 텍스트에서 본문과 퀴즈 영역을 분리 및 분석하는 정밀 파서
  void _parseMarkdownAndQuiz() {
    final markdown = widget.rawMarkdown;
    
    // 다중 퀴즈 헤더 구분선 감지 지원
    int quizIndex = markdown.indexOf("### 📝");
    if (quizIndex == -1) {
      quizIndex = markdown.indexOf("[QUIZ]");
    }
    if (quizIndex == -1) {
      quizIndex = markdown.indexOf("### [QUIZ]");
    }
    
    if (quizIndex == -1) {
      setState(() {
        _bodyMarkdown = markdown;
        _quizQuestion = "";
        _quizOptions = [];
      });
      return;
    }

    _bodyMarkdown = markdown.substring(0, quizIndex).trim();
    final quizSection = markdown.substring(quizIndex);

    // 퀴즈 문제 및 보기 파싱
    final lines = quizSection.split('\n');
    String question = "";
    List<String> options = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith("### 📝") || 
          trimmed.startsWith("[QUIZ]") || 
          trimmed.startsWith("### [QUIZ]") ||
          trimmed.startsWith("**문제:**") || 
          trimmed.startsWith("Q.")) {
        question += "$trimmed\n";
      } else if (trimmed.startsWith("1.") || 
                 trimmed.startsWith("2.") || 
                 trimmed.startsWith("3.") || 
                 trimmed.startsWith("4.") ||
                 trimmed.startsWith("1)") || 
                 trimmed.startsWith("2)") || 
                 trimmed.startsWith("3)") || 
                 trimmed.startsWith("4)") ||
                 trimmed.startsWith("- (") ||
                 trimmed.startsWith("* (")) {
        options.add(trimmed);
      }
    }

    setState(() {
      _quizQuestion = question.trim();
      _quizOptions = options;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 강의 본문 마크다운 렌더링
          MarkdownBody(
            data: _bodyMarkdown,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(height: 1.7, fontSize: 16),
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 24,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              code: TextStyle(
                backgroundColor: theme.colorScheme.surfaceVariant,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          
          if (_quizQuestion.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(thickness: 1.5),
            const SizedBox(height: 24),
            
            // 2. 동적 대화형 퀴즈 카드 렌더링 (Premium UI/UX)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                key: const ValueKey('interactive-quiz-card'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.quiz_rounded, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          '실시간 메타인지 평가',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _quizQuestion.replaceAll(RegExp(r'### 📝 |Q\.|\*\*문제:\*\*|\[QUIZ\]\s*|### \[QUIZ\]\s*'), '').trim(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 보기 선택 리스트
                    ..._quizOptions.map((option) {
                      final isSelected = _selectedOption == option;
                      
                      Color optionBorderColor = isSelected 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.outline.withOpacity(0.3);
                      Color optionBgColor = isSelected 
                          ? theme.colorScheme.primary.withOpacity(0.04)
                          : Colors.transparent;

                      // 채점 완료 피드백 결과에 따른 시각 피드백 분기
                      if (widget.quizFeedback != null && isSelected) {
                        final isCorrect = widget.quizFeedback!['isCorrect'] as bool? ?? false;
                        optionBorderColor = isCorrect ? Colors.green : Colors.red;
                        optionBgColor = isCorrect ? Colors.green.shade50.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.3);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: optionBorderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            color: optionBgColor,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: RadioListTile<String>(
                              title: Text(
                                option,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              value: option,
                              groupValue: _selectedOption,
                              activeColor: widget.quizFeedback != null
                                  ? ((widget.quizFeedback!['isCorrect'] as bool? ?? false) ? Colors.green : Colors.red)
                                  : theme.colorScheme.primary,
                              onChanged: widget.quizFeedback != null ? null : (val) {
                                setState(() {
                                  _selectedOption = val;
                                });
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    // 3. 확신도 선택 영역 (보기를 골랐을 때 자연스럽게 페이드인처럼 등장)
                    if (_selectedOption != null && widget.quizFeedback == null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.psychology_rounded, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            '🤔 이 답안에 대해 스스로 얼마나 확신하시나요?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildConfidenceButton('CONFIDENT', '확실히 알고 씀', Colors.green),
                          const SizedBox(width: 8),
                          _buildConfidenceButton('UNSURE', '헷갈림 / 찍음', Colors.orange),
                          const SizedBox(width: 8),
                          _buildConfidenceButton('GUESSED', '완전히 모름', Colors.red),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    
                    // 4. 피드백 결과 또는 제출 버튼 렌더링
                    if (widget.quizFeedback != null) ...[
                      _buildFeedbackWidget(theme),
                    ] else ...[
                      // 제출 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _selectedOption == null || _selectedConfidence == null || widget.isSubmitting
                              ? null
                              : () => widget.onQuizSubmit(_selectedOption!, _selectedConfidence!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: widget.isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '메타인지 답안 제출 및 채점하기',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  /// 확신도 버튼 생성 위젯
  Widget _buildConfidenceButton(String value, String label, Color color) {
    final isSelected = _selectedConfidence == value;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedConfidence = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.grey.shade50,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// 메타인지 요약 리포트를 동적으로 그려주는 프리미엄 피드백 위젯
  Widget _buildFeedbackWidget(ThemeData theme) {
    final isCorrect = widget.quizFeedback!['isCorrect'] as bool? ?? false;
    final explanation = widget.quizFeedback!['feedback'] as String? ?? '';
    final status = widget.quizFeedback!['metaCognitionStatus'] as String? ?? 'safe';

    Color cardColor = Colors.green;
    String statusTitle = "안전지대 (완벽 내재화) 🟢";
    String statusSub = "축하합니다! 개념을 정확히 알고 맞추셨습니다.";
    IconData statusIcon = Icons.verified_user_rounded;

    switch (status) {
      case 'safe':
        cardColor = Colors.green.shade600;
        statusTitle = "안전 지대 (완벽 내재화) 🟢";
        statusSub = "개념을 완벽하게 알고 맞추셨습니다. 실무에 바로 적용 가능한 튼튼한 지식입니다!";
        statusIcon = Icons.verified_user_rounded;
        break;
      case 'warning_guessed':
        cardColor = Colors.blue.shade600;
        statusTitle = "보완 구역 (어설픈 지식) 🔵";
        statusSub = "정답은 맞췄으나 헷갈리거나 찍으신 문항입니다. 다음에 틀릴 가능성이 높으므로 아래 해설을 정독하세요!";
        statusIcon = Icons.help_outline_rounded;
        break;
      case 'warning_illusion':
        cardColor = Colors.orange.shade700;
        statusTitle = "착각 구역 (개념 왜곡 경고) 🟠";
        statusSub = "[경고!] 스스로 안다고 100% 확신하셨지만 오답이 났습니다. 지식의 혼동을 바로잡는 강도 높은 재학습이 요구됩니다.";
        statusIcon = Icons.report_problem_rounded;
        break;
      case 'danger_unknown':
        cardColor = Colors.red.shade700;
        statusTitle = "재학습 구역 (개념 무지) 🔴";
        statusSub = "법안에 대한 이해도가 현저히 낮아 틀린 문항입니다. 기초 내용과 핵심 지침을 다시 학습하시기 바랍니다.";
        statusIcon = Icons.dangerous_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: cardColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                    color: cardColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusSub,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            '상세 컴플라이언스 법리 해설',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: cardColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
