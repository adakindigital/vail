import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/chat_input.dart';
import 'package:vail_app/views/chat/widgets/message_bubble.dart';
import 'package:vail_app/views/chat/widgets/response_insight_card.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

const int _kInsightThreshold = 400;

/// Mobile chat UI — Forest Sanctuary layout.
///
/// Glassmorphic top bar, pill model selector, reversed message list,
/// gradient-faded pill input fixed above bottom nav.
class ChatViewMobile extends StatelessWidget {
  final void Function(int) onSwitchTab;
  final void Function(String input, {Uint8List? imageBytes}) onSend;

  const ChatViewMobile({
    required this.onSwitchTab,
    required this.onSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(statusTop: MediaQuery.of(context).padding.top),
        // Error banner
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
        // Message list
        Expanded(
          child: Selector<ChatViewModel, int>(
            selector: (_, vm) => vm.changeCount,
            builder: (context, count, child) {
              final vm = context.read<ChatViewModel>();
              final messages = vm.messages;
              if (messages.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.only(
                  top: VailTheme.md,
                  bottom: VailTheme.xxl,
                ),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msgIndex = messages.length - 1 - index;
                  final msg = messages[msgIndex];

                  final showInsight = msg.isFromAssistant &&
                      !msg.isStreaming &&
                      msg.content.length >= _kInsightThreshold &&
                      !vm.isInsightCardDismissed(msgIndex);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MessageBubble(message: msg, index: msgIndex),
                      if (showInsight)
                        ResponseInsightCard(
                          mode: resolveInsightMode(
                              msg.model ?? vm.activeModel, false),
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
        // Input
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

// ── Glassmorphic header ───────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final double statusTop;

  const _ChatHeader({required this.statusTop});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        padding: EdgeInsets.only(
          top: statusTop + VailTheme.sm,
          left: VailTheme.lg,
          right: VailTheme.lg,
          bottom: VailTheme.sm,
        ),
        decoration: BoxDecoration(
          color: VailTheme.background.withValues(alpha: 0.95),
          border: const Border(
            bottom: BorderSide(color: VailTheme.ghostBorder),
          ),
        ),
        child: Row(
          children: [
            // Brand
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco_rounded,
                    color: VailTheme.primary, size: 20),
                const SizedBox(width: VailTheme.xs + 2),
                Text(
                  'Vail AI',
                  style: VailTheme.heading.copyWith(
                    color: VailTheme.primary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Model tier segmented pill
            Selector<ChatViewModel, String>(
              selector: (_, vm) => vm.activeModel,
              builder: (context, model, child) => _ModelSegmentedPill(
                activeModel: model,
                onSelect: (tier) {
                  if (AppConstants.isPremiumTier(tier)) {
                    _showUpgradeDialog(context, tier);
                  } else {
                    context.read<ChatViewModel>().setModel(tier);
                  }
                },
              ),
            ),
            const SizedBox(width: VailTheme.sm),
            // New chat
            GestureDetector(
              onTap: () => context.read<ChatViewModel>().startNewSession(),
              child: Container(
                padding: const EdgeInsets.all(VailTheme.xs + 2),
                decoration: BoxDecoration(
                  border: Border.all(color: VailTheme.ghostBorder),
                  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: VailTheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpgradeDialog(BuildContext context, String tier) async {
    final proceed = await showVailDialog<bool>(
      context: context,
      title: 'Upgrade required',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.sm,
              vertical: VailTheme.xs,
            ),
            decoration: BoxDecoration(
              color: VailTheme.primaryContainer,
              borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              border: Border.all(
                color: VailTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              AppConstants.modelDisplayName(tier),
              style: VailTheme.caption.copyWith(color: VailTheme.primary),
            ),
          ),
          const SizedBox(height: VailTheme.md),
          Text(
            AppConstants.modelDescription(tier),
            style: VailTheme.body.copyWith(color: VailTheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: const [
        VailDialogAction(label: 'Cancel', value: false),
        VailDialogAction(label: 'Upgrade', value: true, isPrimary: true),
      ],
    );
    if (proceed == true && context.mounted) showUpgradeSheet(context);
  }
}

// ── Model segmented pill (Lite / Core / Pro) ──────────────────────────────────

class _ModelSegmentedPill extends StatelessWidget {
  final String activeModel;
  final void Function(String) onSelect;

  const _ModelSegmentedPill({
    required this.activeModel,
    required this.onSelect,
  });

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
            onTap: () => onSelect(t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: VailTheme.md,
                vertical: VailTheme.xs + 1,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? VailTheme.primary.withValues(alpha: 0.15)
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
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Forest Sanctuary empty state ──────────────────────────────────────────────

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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.xxl,
          vertical: VailTheme.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            // Emerald eco icon in a glow circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: VailTheme.primary.withValues(alpha: 0.25),
                ),
                boxShadow: VailTheme.aiCardGlow,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: VailTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: VailTheme.lg),
            Text(
              'Vail AI',
              style: VailTheme.display.copyWith(color: VailTheme.primary),
            ),
            const SizedBox(height: VailTheme.xs),
            Text(
              'Forest Sanctuary',
              style: VailTheme.caption.copyWith(
                color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: VailTheme.xxl),
            Text(
              'How can I help you today?',
              style: VailTheme.subheading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.md),
            Text(
              'Your intelligent layer — built to think, write, analyse, and assist across everything you do.',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xxl),
            // Capability hints
            ..._hints.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: VailTheme.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
            const Spacer(),
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
