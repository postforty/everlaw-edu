import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../providers/chatbot_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class InlineChatbotSheet extends ConsumerStatefulWidget {
  final String? lawReference;
  final String? initialContext;

  const InlineChatbotSheet({
    super.key,
    this.lawReference,
    this.initialContext,
  });

  /// 바텀 시트를 우아하게 호출하는 공통 유틸리티 메소드
  static void show(BuildContext context, String? lawReference, {String? initialContext}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => InlineChatbotSheet(
        lawReference: lawReference,
        initialContext: initialContext,
      ),
    );
  }

  @override
  ConsumerState<InlineChatbotSheet> createState() => _InlineChatbotSheetState();
}

class _InlineChatbotSheetState extends ConsumerState<InlineChatbotSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialContext != null && widget.initialContext!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 바텀시트가 열리는 애니메이션이 끝난 후 메시지가 추가되도록 딜레이 부여
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _handleSend(widget.initialContext!);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 메시지가 추가될 때 항상 스크롤을 최하단으로 부드럽게 내림
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSend(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    
    final chatbotNotifier = ref.read(chatbotMessagesProvider(widget.lawReference).notifier);
    await chatbotNotifier.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatbotMessagesProvider(widget.lawReference));
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 메시지 상태 변경 시 스크롤 동기화 트리거
    ref.listen<List<ChatMessage>>(chatbotMessagesProvider(widget.lawReference), (prev, next) {
      _scrollToBottom();
    });

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. 드래그 핸들 및 헤더
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gavel_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI 준법 실시간 자문 비서',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          if (widget.lawReference != null)
                            Text(
                              '기준 맥락: ${widget.lawReference}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // 2. 메시지 리스트 스크롤 영역
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.sender == ChatSender.user;

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: isUser 
                              ? theme.colorScheme.primary 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Builder(
                          builder: (context) {
                            String displayText = msg.text;
                            if (!isUser) {
                              // flutter_markdown의 인라인 파싱 한계를 우회하기 위해 **"텍스트"** 를 "**텍스트**" 로 치환
                              // 또한 **텍스트(부가설명)** 처럼 괄호가 포함된 경우 **텍스트**(부가설명) 으로 치환
                              displayText = displayText
                                  .replaceAllMapped(RegExp(r'\*\*"([^"]+)"\*\*'), (m) => '"**${m.group(1)}**"')
                                  .replaceAllMapped(RegExp(r"\*\*'([^']+)'\*\*"), (m) => "'**${m.group(1)}**'")
                                  .replaceAllMapped(RegExp(r'\*\*(.*?)(\s*)\(([^\)]+)\)\*\*', dotAll: true), (m) => '**${m.group(1)}**${m.group(2)}(${m.group(3)})');
                            }
                            
                            if (!isUser && displayText.contains('교차 확인하고 있습니다')) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      displayText,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14.0,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return isUser 
                                ? Text(
                                    displayText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      height: 1.5,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: displayText,
                                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                      p: const TextStyle(color: Colors.black87, fontSize: 14.5, height: 1.5),
                                      strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                                      listBullet: const TextStyle(color: Colors.black87, fontSize: 14.5, height: 1.5),
                                    ),
                                  );
                          }
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. 추천 빠른 질문 칩 영역
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickChip('💡 법적 의무 사항'),
                    _buildQuickChip('⚖️ 위반 시 처벌 수치'),
                    _buildQuickChip('🏗️ 실제 위반 사례'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4. 전송 입력 영역
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: '궁금한 조항이나 키워드를 질문해 보세요...',
                              hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(fontSize: 14.5),
                            onSubmitted: _handleSend,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _handleSend(_textController.text),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _handleSend(label),
      ),
    );
  }
}
