import 'package:flutter/material.dart';

class AiValidationCard extends StatelessWidget {
  final double hallucinationScore; // 0.0 ~ 1.0 (낮을수록 안전)
  final String validationDetails;
  
  const AiValidationCard({
    super.key,
    required this.hallucinationScore,
    required this.validationDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSafe = hallucinationScore <= 0.3;
    final isWarning = hallucinationScore > 0.3 && hallucinationScore < 0.7;
    
    Color scoreColor = Colors.green.shade600;
    String riskText = "안전 (Safe)";
    IconData riskIcon = Icons.verified_user_rounded;
    
    if (isWarning) {
      scoreColor = Colors.orange.shade700;
      riskText = "수동 검토 요망 (Warning)";
      riskIcon = Icons.warning_amber_rounded;
    } else if (hallucinationScore >= 0.7) {
      scoreColor = Colors.red.shade700;
      riskText = "환각 위험 심각 (Danger)";
      riskIcon = Icons.dangerous_rounded;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
      ),
      color: scoreColor.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(riskIcon, color: scoreColor, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'AI 자가 감사 결과 리포트',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskText,
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // 1. 점수 게이지 시각화
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: hallucinationScore,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Text(
                      '${(hallucinationScore * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // 2. 환각 위험 설명 요약
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '환각 지수 (Hallucination Score)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSafe 
                            ? 'AI 자가 검토 결과 최신 법령의 수치 및 기한이 정확히 일치하여 배포에 완벽히 적합합니다.'
                            : isWarning 
                                ? '법령의 중요 수치(벌금, 기한 등)의 잠재적 오차가 확인되어 즉시 수동 확인을 진행해 주세요.'
                                : '중요한 왜곡 조항이나 잘못 기술된 수치(환각)가 강력하게 의심됩니다. 반려 조치를 권고합니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            // 3. 상세 감사 소견 (validation_details) 아코디언 컴포넌트
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  '상세 교차 감사 소견 보기',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                leading: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      validationDetails,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
