import 'package:flutter/material.dart';
import '../../features/quiz/models/quiz_item.dart';

class StandaloneQuizCard extends StatefulWidget {
  final QuizItem quiz;
  final Function(bool isCorrect) onAnswerSelected;
  final VoidCallback onChatbotRequested;
  final VoidCallback? onNextPressed;

  const StandaloneQuizCard({
    super.key,
    required this.quiz,
    required this.onAnswerSelected,
    required this.onChatbotRequested,
    this.onNextPressed,
  });

  @override
  State<StandaloneQuizCard> createState() => _StandaloneQuizCardState();
}

class _StandaloneQuizCardState extends State<StandaloneQuizCard> with SingleTickerProviderStateMixin {
  String? _selectedOption;
  bool? _isCorrect;
  late AnimationController _swipeAnimController;

  @override
  void initState() {
    super.initState();
    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StandaloneQuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quiz.id != widget.quiz.id) {
      _selectedOption = null;
      _isCorrect = null;
    }
  }

  void _handleSelection(String option) {
    if (_selectedOption != null) return; // 이미 답을 고른 경우 무시

    setState(() {
      _selectedOption = option;
      _isCorrect = option == widget.quiz.correctAnswer;
    });

    widget.onAnswerSelected(_isCorrect!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                '일일 실전 모의고사',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.quiz.question,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.4,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 40),
          ...widget.quiz.options.map((option) {
            final isSelected = _selectedOption == option;
            final isAnswered = _selectedOption != null;
            final isThisCorrect = option == widget.quiz.correctAnswer;

            Color borderColor = Colors.grey.shade300;
            Color bgColor = Colors.transparent;
            Color textColor = Colors.black87;
            IconData? trailingIcon;

            if (isAnswered) {
              if (isThisCorrect) {
                borderColor = Colors.green;
                bgColor = Colors.green.shade50;
                textColor = Colors.green.shade800;
                trailingIcon = Icons.check_circle_rounded;
              } else if (isSelected) {
                borderColor = Colors.red;
                bgColor = Colors.red.shade50;
                textColor = Colors.red.shade800;
                trailingIcon = Icons.cancel_rounded;
              } else {
                textColor = Colors.grey;
              }
            } else if (isSelected) {
              borderColor = theme.colorScheme.primary;
              bgColor = theme.colorScheme.primary.withValues(alpha: 0.05);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                onTap: isAnswered ? null : () => _handleSelection(option),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: isSelected || (isAnswered && isThisCorrect) ? 2 : 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: (isSelected || (isAnswered && isThisCorrect)) ? FontWeight.bold : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: borderColor),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          // 오답 시 해설 패널 표시
          if (_isCorrect != null && !_isCorrect!) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '오답 해설',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.quiz.explanation,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade900, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onChatbotRequested,
                      icon: const Icon(Icons.smart_toy_rounded, size: 18),
                      label: const Text(
                        'AI 도우미에게 상세 질문하기',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (widget.onNextPressed != null) ...[
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: widget.onNextPressed,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _swipeAnimController,
                          builder: (context, child) {
                            final double animValue = _swipeAnimController.value;
                            
                            // 오른쪽(+24)에서 시작해서 왼쪽(-24)으로 쓸어가는 단방향 궤적
                            final double xOffset = 24.0 - (animValue * 48.0);
                            
                            // 자연스럽게 나타났다가 쓸어가면서 서서히 사라지는(Fade Out) 루프 보간
                            double opacity = 0.0;
                            if (animValue < 0.2) {
                              opacity = (animValue / 0.2) * 0.75;
                            } else {
                              opacity = 0.75 * (1.0 - (animValue - 0.2) / 0.8);
                            }

                            return SizedBox(
                              height: 32,
                              child: Transform.translate(
                                offset: Offset(xOffset, 0),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Icon(
                                    Icons.touch_app_rounded,
                                    color: Colors.grey.shade400,
                                    size: 28,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
