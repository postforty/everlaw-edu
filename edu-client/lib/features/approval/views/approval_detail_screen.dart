import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/ai_validation_card.dart';
import '../../../core/widgets/markdown_quiz_renderer.dart';
import '../models/approval_request.dart';
import '../providers/approval_provider.dart';

class ApprovalDetailScreen extends ConsumerStatefulWidget {
  final ApprovalRequest request;

  const ApprovalDetailScreen({
    super.key,
    required this.request,
  });

  @override
  ConsumerState<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends ConsumerState<ApprovalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionState = ref.watch(approvalActionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '교안 컴플라이언스 정밀 검토 및 대조 뷰어',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: ResponsiveLayout(
        // 1. 모바일 뷰: 위아래로 길게 배치 (우선 자가 리포트 ➡️ 법령 팩트 ➡️ AI 생산 교안 순)
        mobileBody: _buildMobileLayout(theme),
        // 2. 웹/데스크톱 뷰: Side-by-Side (좌측: 근거 법령 팩트 vs 우측: AI 교안 & 자가 감사 리포트)
        webBody: _buildWebSideBySideLayout(theme),
      ),
      // 3. 의사결정 하단 바
      bottomNavigationBar: _buildBottomActionBar(theme, actionState),
    );
  }

  /// 웹용 좌우 1대1 대조(Side-by-Side) 레이아웃
  Widget _buildWebSideBySideLayout(ThemeData theme) {
    return Row(
      children: [
        // 좌측 패널: 최신 법령 조문 팩트 (Ground Truth)
        Expanded(
          flex: 45,
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 24, 12, 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '근거 최신 법령 팩트 (Ground Truth)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 엔진 RAG가 법률 전문 DB에서 실시간 청킹 및 연계 추적한 원천 법규 정보입니다. 이 데이터의 의도와 수치가 최종 교안에 100% 무왜곡 반영되어야 합니다.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '근거 참조 법규: ${widget.request.lawReference}',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _getMockLawReferenceBody(widget.request.lawReference),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          fontFamily: 'NanumGothic',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 우측 패널: AI 생성 교안 프리뷰 & 자가검증 감사 결과 리포트
        Expanded(
          flex: 55,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 24, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // 상단 탭/헤더 느낌의 연동
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI 생산 강의안 및 모의 평가 프리뷰',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 우측 스크롤 영역
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AI 자가 검증 리포트 (Circular progress gauge + accordion validation 소견 포함)
                          AiValidationCard(
                            hallucinationScore: widget.request.hallucinationScore,
                            validationDetails: widget.request.validationDetails,
                          ),
                          const SizedBox(height: 24),
                          
                          // 마크다운 동적 파싱 렌더러 위젯 호출
                          // (프리뷰 화면이므로 실시간 풀이 제출은 디버깅 모의 콜백 연동)
                          MarkdownQuizRenderer(
                            rawMarkdown: widget.request.aiGeneratedMarkdown,
                            onQuizSubmit: (selected, confidence) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('프리뷰 모드 제출 답안 감지: $selected ($confidence)')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 모바일 레이아웃 (스크롤 가능한 리스트 구조로 세로 정렬)
  Widget _buildMobileLayout(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. AI 자가 감사 결과 리포트
          AiValidationCard(
            hallucinationScore: widget.request.hallucinationScore,
            validationDetails: widget.request.validationDetails,
          ),
          const SizedBox(height: 16),
          
          // 2. 근거 법령 조문 팩트 요약 카드
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ExpansionTile(
                title: Text(
                  '최신 법령 조문 팩트 보기',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                leading: Icon(Icons.gavel_rounded, color: theme.colorScheme.primary),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade50,
                    child: Text(
                      _getMockLawReferenceBody(widget.request.lawReference),
                      style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 3. AI 생성 강의 마크다운
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '생산 교안 본문 및 퀴즈',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  MarkdownQuizRenderer(
                    rawMarkdown: widget.request.aiGeneratedMarkdown,
                    onQuizSubmit: (selected, confidence) {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 승인/반려 의사결정 하단 액션 바
  Widget _buildBottomActionBar(ThemeData theme, AsyncValue<void> actionState) {
    final isLoading = actionState is AsyncLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 반려(Reject) 버튼
            SizedBox(
              height: 48,
              width: 140,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => _handleDecision(context, false),
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text(
                  '교안 반려',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 승인 및 공식 배포(Approve) 버튼
            SizedBox(
              height: 48,
              width: 180,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _handleDecision(context, true),
                icon: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text(
                  '검토 최종 승인',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 승인/반려 의사결정 처리 플로우
  void _handleDecision(BuildContext context, bool approved) async {
    final notifier = ref.read(approvalActionNotifierProvider.notifier);
    
    final success = await notifier.processAction(
      requestId: widget.request.id,
      approved: approved,
      adminEmail: ref.read(adminEmailProvider),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  approved ? Icons.verified_user_rounded : Icons.report_gmailerrorred_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    approved 
                        ? '해당 교안이 최종 승인되었습니다. 학습자용 배포 및 푸시 알림이 발송되었습니다.' 
                        : '교안 검토가 반려 처리되었습니다.',
                  ),
                ),
              ],
            ),
            backgroundColor: approved ? Colors.green.shade800 : Colors.red.shade800,
          ),
        );
        Navigator.pop(context);
      } else {
        final error = ref.read(approvalActionNotifierProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('처리 중 실패 에러가 발생하였습니다: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 팩트 대조를 보조하기 위해 법령 식별 키에 따른 조항의 가상 원본 내용을 서빙
  String _getMockLawReferenceBody(String lawRef) {
    if (lawRef.contains("중대재해") || lawRef.contains("safety")) {
      return """
### 중대재해 처벌 등에 관한 법률
**제4조 (사업주와 경영책임자등의 안전 및 보건 확보의무)**

① 사업주 또는 경영책임자등은 실질적으로 지배ㆍ운영ㆍ관리하는 사업 또는 사업장 및 종사자의 안전ㆍ보건상 유해 또는 위험을 방지하기 위하여 다음 각 호에 따른 조치를 하여야 한다.
1. 재해예방에 필요한 인력 및 예산 등 안전보건관리체계의 구축 및 그 이행에 관한 조치
2. 재해 발생 시 재발방지 대책의 수립 및 그 이행에 관한 조치
3. 중앙행정기관ㆍ지방자치단체가 관계 법령에 따라 개선, 시정 등을 명한 사항의 이행에 관한 조치
4. 안전ㆍ보건 관계 법령에 따른 의무이행에 필요한 관리상의 조치

**제6조 (중대산업재해 사업주 및 경영책임자등의 처벌)**

① 제4조 또는 제5조를 위반하여 제2조제2호가목의 중대산업재해에 이르게 한 사업주 또는 경영책임자등은 1년 이상의 징역 또는 10억원 이하의 벌금에 처한다. 이 경우 징역과 벌금은 병과할 수 있다.
② 제4조 또는 제5조를 위반하여 제2조제2호가목의 중대산업재해에 이르게 한 법인 또는 기관은 50억원 이하의 벌금에 처한다.
""";
    } else if (lawRef.contains("근로기준") || lawRef.contains("labor")) {
      return """
### 근로기준법
**제53조 (연장 근로의 제한)**

① 당사자 간에 합의하면 1주간에 12시간을 한도로 제50조의 근로시간을 연장할 수 있다.
② 당사자 간에 합의하면 1주간에 12시간을 한도로 제51조 및 제51조의2의 근로시간을 연장할 수 있고, 제52조제1항제2호의 정산기간을 평균하여 1주간에 12시간을 한도로 연장할 수 있다.

**제110조 (벌칙)**

제53조제1항ㆍ제2항을 위반한 자는 2년 이하의 징역 또는 2천만원 이하의 벌금에 처한다.
""";
    } else {
      return """
### 산업안전보건법
**제38조 (안전조치)**

① 사업주는 다음 각 호의 어느 하나에 해당하는 위험으로 인한 산업재해를 예방하기 위하여 필요한 조치를 하여야 한다.
1. 기계ㆍ기구, 그 밖의 설비에 의한 위험
2. 폭발성, 발화성 및 인화성 물질 등에 의한 위험
3. 전기, 열, 그 밖의 에너지에 의한 위험

② 사업주는 굴착, 채석, 하역, 벌목, 운송, 투고, 해체, 파괴, 그 밖의 작업 방법으로 인하여 발생하는 위험을 예방하기 위하여 필요한 조치를 하여야 한다.
③ 사업주는 추락할 위험이 있는 장소, 토사ㆍ구축물 등이 붕괴할 우려가 있는 장소, 그 밖에 작업 중 위험이 발생할 우려가 있는 장소에는 그 위험을 예방하기 위하여 필요한 조치를 하여야 한다.
""";
    }
  }
}
