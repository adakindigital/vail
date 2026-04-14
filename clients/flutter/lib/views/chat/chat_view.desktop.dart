import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/chat_input.dart';
import 'package:vail_app/views/chat/widgets/message_bubble.dart';
import 'package:vail_app/views/chat/widgets/response_insight_card.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

/// Minimum assistant response length (characters) that triggers the insight card.
const int _kDesktopInsightThreshold = 400;

/// Desktop chat UI — no brand header (the desktop shell owns top-bar context),
/// message list expands to fill the shell's content area.
///
/// Rendered by [ChatView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [ChatView].
class ChatViewDesktop extends StatelessWidget {
  final void Function(int) onSwitchTab;
  final void Function(String input, {Uint8List? imageBytes}) onSend;

  const ChatViewDesktop({
    required this.onSwitchTab,
    required this.onSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // No header — desktop shell's top bar provides context.
        Selector<ChatViewModel, ChatState>(
          selector: (_, vm) => vm.state,
          builder: (context, state, child) {
            if (state != ChatState.error) return const SizedBox.shrink();
            return _ErrorBanner(
              message: context.read<ChatViewModel>().errorMessage,
              onDismiss: () => context.read<ChatViewModel>().dismissError(),
            );
          },
        ),
        Expanded(
          child: Selector<ChatViewModel, int>(
            selector: (_, vm) => vm.changeCount,
            builder: (context, count, child) {
              final vm = context.read<ChatViewModel>();
              final messages = vm.messages;
              if (messages.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: VailTheme.sm),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msgIndex = messages.length - 1 - index;
                  final msg = messages[msgIndex];

                  final showInsight = msg.isFromAssistant &&
                      !msg.isStreaming &&
                      msg.content.length >= _kDesktopInsightThreshold &&
                      !vm.isInsightCardDismissed(msgIndex);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MessageBubble(message: msg, index: msgIndex),
                      if (showInsight)
                        ResponseInsightCard(
                          mode: resolveInsightMode(msg.model ?? vm.activeModel, false),
                          activeModel: msg.model ?? vm.activeModel,
                          onDismiss: () => vm.dismissInsightCard(msgIndex),
                          onUpgrade: () => showUpgradeSheet(context),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Selector<ChatViewModel, bool>(
          selector: (_, vm) => vm.isSending,
          builder: (context, isSending, child) => ChatInput(
            enabled: !isSending,
            onSend: onSend,
            onNewDocument: () => showNewDocumentSheet(context),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(VailTheme.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VAIL', style: VailTheme.wordmark),
              const SizedBox(height: VailTheme.sm),
              Text(
                'VERSATILE ARTIFICIAL INTELLIGENCE LAYER',
                style: VailTheme.mono.copyWith(color: VailTheme.textSecondary),
              ),
              const SizedBox(height: VailTheme.xxl),
              Text(
                'Welcome.',
                style: VailTheme.body.copyWith(color: VailTheme.textPrimary),
              ),
              const SizedBox(height: VailTheme.md),
              Text(
                'Vail is your intelligent layer — built to think, write, analyse, and assist across everything you do. Type a message below to get started.',
                style: VailTheme.bodySmall.copyWith(
                  color: VailTheme.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: VailTheme.xxl),
              const _CapabilityHints(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityHints extends StatelessWidget {
  const _CapabilityHints();

  static const _hints = [
    (icon: Icons.edit_note_rounded, label: 'Draft documents and reports'),
    (icon: Icons.search_rounded, label: 'Research and summarise topics'),
    (icon: Icons.code_rounded, label: 'Write and review code'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Think through complex problems'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _hints.map((hint) => Padding(
        padding: const EdgeInsets.only(bottom: VailTheme.sm),
        child: Row(
          children: [
            Icon(hint.icon, size: 13, color: VailTheme.accent),
            const SizedBox(width: VailTheme.sm),
            Text(
              hint.label,
              style: VailTheme.bodySmall.copyWith(color: VailTheme.textSecondary),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.sm,
      ),
      color: VailTheme.error.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: VailTheme.error, size: 16),
          const SizedBox(width: VailTheme.sm),
          Expanded(
            child: Text(
              message,
              style: VailTheme.bodySmall.copyWith(color: VailTheme.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, color: VailTheme.error, size: 16),
          ),
        ],
      ),
    );
  }
}
