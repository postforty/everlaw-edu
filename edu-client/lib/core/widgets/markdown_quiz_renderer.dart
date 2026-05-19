import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownQuizRenderer extends StatefulWidget {
  final String rawMarkdown;
  final Function(String selectedAnswer) onQuizSubmit;
  final bool isSubmitting;
  final Map<String, dynamic>? quizFeedback; // { "correct": bool, "explanation": String }

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
    // 피드백이 새로 들어오거나 퀴즈가 초기화되면 선택 상태 초기화 처리
    if (widget.quizFeedback == null && oldWidget.quizFeedback != null) {
      _selectedOption = null;
    }
  }

  /// 마크다운 텍스트에서 본문과 퀴즈 영역을 분리 및 분석하는 정밀 파서
  void _parseMarkdownAndQuiz() {
    final markdown = widget.rawMarkdown;
    // 퀴즈 헤더 구분선 감지 ("### 📝 모의 평가 퀴즈" 또는 "### 📝 실시간 모의 평가 퀴즈")
    final int quizIndex = markdown.indexOf("### 📝");
    
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
      if (trimmed.startsWith("### 📝") || trimmed.startsWith("**문제:**") || trimmed.startsWith("Q.")) {
        question += "$trimmed\n";
      } else if (trimmed.startsWith("1.") || 
                 trimmed.startsWith("2.") || 
                 trimmed.startsWith("3.") || 
                 trimmed.startsWith("4.") ||
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
                          '실시간 지식 평가',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _quizQuestion.replaceAll(RegExp(r'### 📝 |Q\.|\*\*문제:\*\*'), '').trim(),
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
                      final isCorrectAnswer = widget.quizFeedback != null && 
                          widget.quizFeedback!['correct'] == true && 
                          isSelected;
                      
                      Color optionBorderColor = isSelected 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.outline.withOpacity(0.3);
                      Color optionBgColor = isSelected 
                          ? theme.colorScheme.primary.withOpacity(0.04)
                          : Colors.transparent;

                      // 채점 완료 피드백 결과에 따른 시각 피드백 분기
                      if (widget.quizFeedback != null && isSelected) {
                        final isCorrect = widget.quizFeedback!['correct'] as bool;
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
                                ? (widget.quizFeedback!['correct'] as bool ? Colors.green : Colors.red)
                                : theme.colorScheme.primary,
                            onChanged: widget.quizFeedback != null ? null : (val) {
                              setState(() {
                                _selectedOption = val;
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 16),
                    
                    // 3. 피드백 결과 또는 제출 버튼 렌더링
                    if (widget.quizFeedback != null) ...[
                      _buildFeedbackWidget(theme),
                    ] else ...[
                      // 제출 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _selectedOption == null || widget.isSubmitting
                              ? null
                              : () => widget.onQuizSubmit(_selectedOption!),
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
                                  '답안 제출 및 실시간 채점하기',
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

  Widget _buildFeedbackWidget(ThemeData theme) {
    final isCorrect = widget.quizFeedback!['correct'] as bool;
    final explanation = widget.quizFeedback!['explanation'] as String;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.shade50.withOpacity(0.5) 
            : Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.shade400 : Colors.red.shade400,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '정답입니다! 🟢' : '오답입니다. 다시 한 번 학습해보세요! 🔴',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCorrect ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '상세 해설',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
