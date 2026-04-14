import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/chat_input.dart';
import 'package:vail_app/views/chat/widgets/message_bubble.dart';
import 'package:vail_app/views/chat/widgets/response_insight_card.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

const int _kDesktopInsightThreshold = 400;

/// Desktop chat UI — Forest Sanctuary layout.
///
/// Top bar with Lite/Core/Pro segmented pill + Share action.
/// Centred message feed with max-width constraint.
/// Gradient-faded input area at bottom.
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
        _DesktopChatTopBar(),
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
                padding: const EdgeInsets.only(
                  top: VailTheme.xl,
                  bottom: VailTheme.xxl + VailTheme.xl,
                ),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msgIndex = messages.length - 1 - index;
                  final msg = messages[msgIndex];

                  final showInsight = msg.isFromAssistant &&
                      !msg.isStreaming &&
                      msg.content.length >= _kDesktopInsightThreshold &&
                      !vm.isInsightCardDismissed(msgIndex);

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MessageBubble(message: msg, index: msgIndex),
                          if (showInsight)
                            ResponseInsightCard(
                              mode: resolveInsightMode(
                                  msg.model ?? vm.activeModel, false),
                              activeModel: msg.model ?? vm.activeModel,
                              onDismiss: () =>
                                  vm.dismissInsightCard(msgIndex),
                              onUpgrade: () => showUpgradeSheet(context),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Selector<ChatViewModel, bool>(
          selector: (_, vm) => vm.isSending,
          builder: (context, isSending, child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ChatInput(
                enabled: !isSending,
                onSend: onSend,
                onNewDocument: () => showNewDocumentSheet(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Desktop top bar ───────────────────────────────────────────────────────────

class _DesktopChatTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.xl),
      decoration: BoxDecoration(
        color: VailTheme.background.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: VailTheme.ghostBorder),
        ),
      ),
      child: Row(
        children: [
          // Model tier segmented pill
          Selector<ChatViewModel, String>(
            selector: (_, vm) => vm.activeModel,
            builder: (context, model, child) =>
                _DesktopModelPill(activeModel: model),
          ),
          const Spacer(),
          // Share chat button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.md,
              vertical: VailTheme.xs + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: VailTheme.ghostBorder),
              borderRadius: BorderRadius.circular(VailTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_rounded,
                    color: VailTheme.primary, size: 14),
                const SizedBox(width: VailTheme.xs + 2),
                Text(
                  'Share chat',
                  style: VailTheme.caption.copyWith(
                    color: VailTheme.primary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopModelPill extends StatelessWidget {
  final String activeModel;

  const _DesktopModelPill({required this.activeModel});

  static const _tiers = [
    ('vail-lite', 'Lite'),
    ('vail', 'Core'),
    ('vail-pro', 'Pro'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(VailTheme.radiusFull),
        border: Border.all(color: VailTheme.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tiers.map((t) {
          final isActive = t.$1 == activeModel;
          return GestureDetector(
            onTap: () {
              if (AppConstants.isPremiumTier(t.$1)) {
                showUpgradeSheet(context);
              } else {
                context.read<ChatViewModel>().setModel(t.$1);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: VailTheme.lg,
                vertical: VailTheme.xs + 1,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? VailTheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
              ),
              child: Text(
                t.$2,
                style: VailTheme.caption.copyWith(
                  color: isActive
                      ? VailTheme.primary
                      : VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const _hints = [
    (icon: Icons.edit_note_rounded, label: 'Draft documents and reports'),
    (icon: Icons.search_rounded, label: 'Research and summarise topics'),
    (icon: Icons.code_rounded, label: 'Write and review code'),
    (icon: Icons.psychology_rounded, label: 'Think through complex problems'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wordmark row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: VailTheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(VailTheme.radiusSm),
                    border: Border.all(
                      color: VailTheme.primary.withValues(alpha: 0.25),
                    ),
                    boxShadow: VailTheme.aiCardGlow,
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: VailTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: VailTheme.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vail AI',
                      style: VailTheme.heading.copyWith(
                        color: VailTheme.primary,
                      ),
                    ),
                    Text(
                      'Forest Sanctuary',
                      style: VailTheme.caption.copyWith(
                        color: VailTheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: VailTheme.xxl),
            Text(
              'How can I help you today?',
              style: VailTheme.heading.copyWith(fontSize: 22),
            ),
            const SizedBox(height: VailTheme.md),
            Text(
              'Your intelligent layer — built to think, write, analyse, and assist across everything you do.',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: VailTheme.xxl),
            ..._hints.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: VailTheme.sm),
                child: Row(
                  children: [
                    Icon(h.icon, size: 14, color: VailTheme.primary),
                    const SizedBox(width: VailTheme.sm),
                    Text(
                      h.label,
                      style: VailTheme.bodySmall.copyWith(
                        color: VailTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
      color: VailTheme.error.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: VailTheme.error, size: 16),
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
