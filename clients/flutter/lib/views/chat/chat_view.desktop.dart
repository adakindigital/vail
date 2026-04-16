import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_advanced_badge.dart';
import 'package:vail_app/core/widgets/vail_error_banner.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/chat_input.dart';
import 'package:vail_app/views/chat/widgets/message_bubble.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

class ChatViewDesktop extends StatelessWidget {
  final void Function(int) onSwitchTab;
  final void Function(String input, {Uint8List? imageBytes}) onSend;

  const ChatViewDesktop({required this.onSwitchTab, required this.onSend, super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    return Column(
      children: [
        const _DesktopChatTopBar(),
        if (vm.state == ChatState.error) VailErrorBanner(message: vm.errorMessage, onDismiss: vm.dismissError),
        Expanded(
          child: vm.messages.isEmpty ? const _EmptyState() : ListView.builder(
            padding: const EdgeInsets.only(top: VailTheme.xl, bottom: VailTheme.xxl),
            reverse: true,
            itemCount: vm.messages.length,
            itemBuilder: (context, index) {
              final msgIndex = vm.messages.length - 1 - index;
              final msg = vm.messages[msgIndex];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: MessageBubble(message: msg, index: msgIndex),
                ),
              );
            },
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ChatInput(enabled: !vm.isSending, onSend: onSend),
          ),
        ),
      ],
    );
  }
}

class _DesktopChatTopBar extends StatelessWidget {
  const _DesktopChatTopBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.xl),
      decoration: BoxDecoration(color: VailTheme.background.withValues(alpha: 0.95), border: const Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
      child: Row(
        children: [
          Selector<ChatViewModel, String>(selector: (_, vm) => vm.activeModel, builder: (context, model, _) => _DesktopModelPill(activeModel: model)),
          const Spacer(),
          const VailAdvancedBadge(),
        ],
      ),
    );
  }
}

class _DesktopModelPill extends StatelessWidget {
  final String activeModel;
  const _DesktopModelPill({required this.activeModel});
  static const _tiers = [('vail-lite', 'Lite'), ('vail', 'Core'), ('vail-pro', 'Pro')];
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: VailTheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(VailTheme.radiusFull), border: Border.all(color: VailTheme.ghostBorder)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tiers.map((t) => GestureDetector(
          onTap: () => AppConstants.isPremiumTier(t.$1)
              ? showUpgradeSheet(
                  context,
                  onProActivated: () {
                    context.read<SettingsViewModel>().setIsPro(true);
                    context.read<ChatViewModel>()
                      ..setModel(t.$1)
                      ..refreshPlan();
                  },
                )
              : context.read<ChatViewModel>().setModel(t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.xs + 1),
            decoration: BoxDecoration(color: t.$1 == activeModel ? VailTheme.primary.withValues(alpha: 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(VailTheme.radiusFull)),
            child: Text(t.$2, style: VailTheme.caption.copyWith(color: t.$1 == activeModel ? VailTheme.primary : VailTheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10)),
          ),
        )).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: VailTheme.primaryContainer, borderRadius: BorderRadius.circular(VailTheme.radiusSm), border: Border.all(color: VailTheme.primary.withValues(alpha: 0.25)), boxShadow: VailTheme.aiCardGlow), child: const Icon(Icons.auto_awesome_rounded, color: VailTheme.primary, size: 22)),
                const SizedBox(width: VailTheme.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Vail AI', style: VailTheme.heading.copyWith(color: VailTheme.primary)), Text('BY ADAKIN DIGITAL', style: VailTheme.caption.copyWith(color: VailTheme.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: 1.5), maxLines: 1, overflow: TextOverflow.ellipsis)])),
              ],
            ),
            const SizedBox(height: VailTheme.xxl),
            Text('How can I help you today?', style: VailTheme.heading.copyWith(fontSize: 22)),
            const SizedBox(height: VailTheme.md),
            Text('Your intelligent layer — built to think, write, analyse, and assist across everything you do.', style: VailTheme.bodySmall.copyWith(color: VailTheme.onSurfaceVariant, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
