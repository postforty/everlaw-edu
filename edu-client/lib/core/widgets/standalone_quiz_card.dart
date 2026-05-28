import 'package:flutter/material.dart';
import '../../features/quiz/models/quiz_item.dart';
import '../theme/app_theme.dart';

class StandaloneQuizCard extends StatefulWidget {
  final QuizItem quiz;
  final Function(bool isCorrect, int selectedIndex) onAnswerSelected;
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

    int selectedIndex = widget.quiz.options.indexOf(option);
    widget.onAnswerSelected(_isCorrect!, selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120), // Extra bottom padding for floating nav
      child: Container(
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.premiumSoft,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                '실전 모의고사',
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
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: (isSelected && !isThisCorrect) ? 0.98 : (isAnswered && isThisCorrect ? 1.02 : 1.0),
                curve: Curves.easeOutBack,
                child: InkWell(
                  onTap: isAnswered ? null : () => _handleSelection(option),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor, width: isSelected || (isAnswered && isThisCorrect) ? 2 : 1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isAnswered ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
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
    ));
  }
}
