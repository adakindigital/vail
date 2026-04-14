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

/// Minimum assistant response length (characters) that triggers the insight card.
const int _kInsightThreshold = 400;

/// Mobile chat UI — full-screen layout with brand header, message list,
/// and input bar. Safe-area padding handled internally.
///
/// Rendered by [ChatView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [ChatView].
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
                      msg.content.length >= _kInsightThreshold &&
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

// ── Header ────────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final double statusTop;

  const _ChatHeader({required this.statusTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: statusTop + VailTheme.md,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.md,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          Selector<ChatViewModel, String>(
            selector: (_, vm) => vm.activeModel,
            builder: (context, model, child) => _ModelChip(
              model: model,
              onTap: () => _showModelPicker(context, model),
            ),
          ),
          const SizedBox(width: VailTheme.sm),
          const _TierBadge(isPro: false), // TODO: wire to auth/subscription state
          const Spacer(),
          _NewChatButton(
            onTap: () => context.read<ChatViewModel>().startNewSession(),
          ),
        ],
      ),
    );
  }

  void _showModelPicker(BuildContext context, String activeModel) {
    final vm = context.read<ChatViewModel>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ModelPickerSheet(
        activeModel: activeModel,
        onSelect: (model) {
          vm.setModel(model);
          Navigator.of(sheetContext).pop();
        },
        onUpgradeRequired: (model) {
          Navigator.of(sheetContext).pop();
          _showUpgradeDialog(context, model);
        },
      ),
    );
  }

  Future<void> _showUpgradeDialog(BuildContext context, String tier) async {
    final proceed = await showVailDialog<bool>(
      context: context,
      title: 'UPGRADE REQUIRED',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VailTheme.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5C07B).withValues(alpha: 0.1),
                  border: Border.all(
                    color: const Color(0xFFE5C07B).withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  AppConstants.modelDisplayName(tier),
                  style: VailTheme.mono.copyWith(
                    color: const Color(0xFFE5C07B),
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: VailTheme.sm),
              Text(
                'PRO PLAN REQUIRED',
                style: VailTheme.mono.copyWith(
                  color: VailTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: VailTheme.md),
          Text(
            AppConstants.modelDescription(tier),
            style: VailTheme.body.copyWith(color: VailTheme.textSecondary),
          ),
          const SizedBox(height: VailTheme.md),
          const Divider(height: 1, color: VailTheme.border),
          const SizedBox(height: VailTheme.md),
          for (final feature in _premiumFeatures(tier))
            Padding(
              padding: const EdgeInsets.only(bottom: VailTheme.sm),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded,
                      color: VailTheme.accent, size: 12),
                  const SizedBox(width: VailTheme.sm),
                  Text(feature, style: VailTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
      actions: const [
        VailDialogAction(label: 'CANCEL', value: false),
        VailDialogAction(label: 'UPGRADE', value: true, isPrimary: true),
      ],
    );
    if (proceed == true && context.mounted) showUpgradeSheet(context);
  }

  List<String> _premiumFeatures(String tier) => switch (tier) {
        'vail-pro' => [
            'Extended context window',
            'Priority routing',
            'Complex multi-step reasoning',
            'Faster response times',
          ],
        'vail-max' => [
            'Maximum reasoning capability',
            'Largest context window',
            'Dedicated compute allocation',
            'Enterprise-grade SLA',
          ],
        _ => ['Advanced capabilities'],
      };
}

// ── Model chip (header) ───────────────────────────────────────────────────────

class _ModelChip extends StatelessWidget {
  final String model;
  final VoidCallback onTap;

  const _ModelChip({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.md,
          vertical: VailTheme.xs + 2,
        ),
        decoration: BoxDecoration(
          color: VailTheme.accentSubtle,
          border: Border.all(color: VailTheme.accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: VailTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: VailTheme.xs + 2),
            Text(
              AppConstants.modelDisplayName(model),
              style: VailTheme.mono.copyWith(
                color: VailTheme.accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: VailTheme.accent,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tier badge ────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isPro;

  const _TierBadge({required this.isPro});

  @override
  Widget build(BuildContext context) {
    const proColor = Color(0xFFE5C07B);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isPro ? proColor.withValues(alpha: 0.08) : Colors.transparent,
        border: Border.all(
          color: isPro
              ? proColor.withValues(alpha: 0.45)
              : VailTheme.border,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        isPro ? 'PRO' : 'FREE',
        style: VailTheme.mono.copyWith(
          color: isPro ? proColor : VailTheme.textMuted,
          fontSize: 8,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Model picker bottom sheet ─────────────────────────────────────────────────

class _ModelPickerSheet extends StatelessWidget {
  final String activeModel;
  final void Function(String) onSelect;
  final void Function(String) onUpgradeRequired;

  const _ModelPickerSheet({
    required this.activeModel,
    required this.onSelect,
    required this.onUpgradeRequired,
  });

  static const _freeTiers = ['vail-lite', 'vail'];
  static const _proTiers = ['vail-pro', 'vail-max'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VailTheme.surface,
        border: Border(top: BorderSide(color: VailTheme.border)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VailTheme.radiusLg),
          topRight: Radius.circular(VailTheme.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                top: VailTheme.md,
                bottom: VailTheme.sm,
              ),
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: VailTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Sheet header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.lg,
              vertical: VailTheme.md,
            ),
            child: Row(
              children: [
                Text('SELECT MODEL', style: VailTheme.sectionLabel),
                const Spacer(),
                const _TierBadge(isPro: false), // TODO: user tier
              ],
            ),
          ),
          const Divider(height: 1, color: VailTheme.border),
          // Free tier
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, VailTheme.md, VailTheme.lg, VailTheme.sm,
            ),
            child: Text(
              'FREE TIER',
              style: VailTheme.mono
                  .copyWith(color: VailTheme.textMuted, fontSize: 9),
            ),
          ),
          for (final tier in _freeTiers)
            _ModelPickerRow(
              tier: tier,
              isActive: tier == activeModel,
              isPremium: false,
              onTap: () => onSelect(tier),
            ),
          // Pro tier
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.sm,
            ),
            child: Row(
              children: [
                Text(
                  'PRO TIER',
                  style: VailTheme.mono
                      .copyWith(color: VailTheme.textMuted, fontSize: 9),
                ),
                const SizedBox(width: VailTheme.sm),
                _UpgradeTag(),
              ],
            ),
          ),
          for (final tier in _proTiers)
            _ModelPickerRow(
              tier: tier,
              isActive: tier == activeModel,
              isPremium: true,
              isComingSoon: AppConstants.isComingSoonTier(tier),
              onTap: AppConstants.isComingSoonTier(tier)
                  ? () {}
                  : () => onUpgradeRequired(tier),
            ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + VailTheme.lg,
          ),
        ],
      ),
    );
  }
}

class _UpgradeTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE5C07B).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFE5C07B).withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'UPGRADE',
        style: VailTheme.mono.copyWith(
          color: const Color(0xFFE5C07B),
          fontSize: 7,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ModelPickerRow extends StatelessWidget {
  final String tier;
  final bool isActive;
  final bool isPremium;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _ModelPickerRow({
    required this.tier,
    required this.isActive,
    required this.isPremium,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    const proColor = Color(0xFFE5C07B);
    const soonColor = Color(0xFF4A4A4A);

    final nameColor = isActive
        ? VailTheme.accent
        : isComingSoon
            ? soonColor
            : isPremium
                ? proColor.withValues(alpha: 0.65)
                : VailTheme.textSecondary;

    final dotColor = isActive
        ? VailTheme.accent
        : isComingSoon
            ? soonColor
            : isPremium
                ? proColor.withValues(alpha: 0.3)
                : VailTheme.border;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.md,
        ),
        color: isActive ? VailTheme.accentSubtle : Colors.transparent,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: VailTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppConstants.modelDisplayName(tier),
                        style: VailTheme.mono.copyWith(
                          color: nameColor,
                          letterSpacing: 2,
                        ),
                      ),
                      if (isComingSoon) ...[
                        const SizedBox(width: VailTheme.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: VailTheme.xs + 1,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: soonColor),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'SOON',
                            style: VailTheme.mono.copyWith(
                              color: soonColor,
                              fontSize: 7,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppConstants.modelDescription(tier),
                    style: VailTheme.bodySmall.copyWith(
                      color: VailTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_rounded,
                  color: VailTheme.accent, size: 14)
            else if (isComingSoon)
              const Icon(Icons.schedule_rounded,
                  color: soonColor, size: 14)
            else if (isPremium)
              const Icon(Icons.lock_outline_rounded,
                  color: proColor, size: 14),
          ],
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NewChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.md,
          vertical: VailTheme.xs + 2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: VailTheme.accent),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NEW CHAT',
                style: VailTheme.mono.copyWith(color: VailTheme.accent)),
            const SizedBox(width: VailTheme.xs),
            const Icon(Icons.arrow_forward_rounded,
                color: VailTheme.accent, size: 12),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            const Text('VAIL', style: VailTheme.wordmark),
            const SizedBox(height: VailTheme.sm),
            Text(
              'VERSATILE ARTIFICIAL INTELLIGENCE LAYER',
              style: VailTheme.mono.copyWith(color: VailTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xxl),
            Text(
              'Welcome.',
              style: VailTheme.body.copyWith(color: VailTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.md),
            Text(
              'Vail is your intelligent layer — built to think, write, analyse, and assist across everything you do. Type a message below to get started.',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xxl),
            const _CapabilityHints(),
            const Spacer(),
            Text(
              'SYSTEM AGENT  ·  PROVISION STATE: IDLE',
              style: VailTheme.mono.copyWith(
                fontSize: 9,
                color: VailTheme.textMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: VailTheme.sm),
          ],
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
      children: _hints.map((hint) => Padding(
        padding: const EdgeInsets.only(bottom: VailTheme.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
