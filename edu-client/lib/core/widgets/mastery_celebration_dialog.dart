import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class MasteryCelebrationDialog extends StatelessWidget {
  final String lawReference;

  const MasteryCelebrationDialog({super.key, required this.lawReference});

  static void show(BuildContext context, String lawReference) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Mastery Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: MasteryCelebrationDialog(lawReference: lawReference),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie Network URL for celebration animation
              Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_touohxv0.json',
                width: 150,
                height: 150,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
              ),
              const SizedBox(height: 16),
              Text(
                '개념 완벽 정복!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '[$lawReference]\n관련 퀴즈 3회 연속 정답 달성',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '해당 조항의 오답노트가 자동으로 졸업(아카이빙) 처리되었습니다. 개인 취약 지수가 안전 구역으로 초기화됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
