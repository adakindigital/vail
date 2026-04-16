import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_error_banner.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/chat_input.dart';
import 'package:vail_app/views/chat/widgets/message_bubble.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

class ChatViewMobile extends StatelessWidget {
  final void Function(int) onSwitchTab;
  final void Function(String input, {Uint8List? imageBytes}) onSend;
  const ChatViewMobile({required this.onSwitchTab, required this.onSend, super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    return Column(
      children: [
        _ChatHeader(statusTop: MediaQuery.of(context).padding.top),
        if (vm.state == ChatState.error) VailErrorBanner(message: vm.errorMessage, onDismiss: vm.dismissError),
        Expanded(
          child: vm.messages.isEmpty ? const _EmptyState() : ListView.builder(
            padding: const EdgeInsets.only(top: VailTheme.md, bottom: VailTheme.xxl),
            reverse: true,
            itemCount: vm.messages.length,
            itemBuilder: (context, index) {
              final msgIndex = vm.messages.length - 1 - index;
              return MessageBubble(message: vm.messages[msgIndex], index: msgIndex);
            },
          ),
        ),
        ChatInput(enabled: !vm.isSending, onSend: onSend),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final double statusTop;
  const _ChatHeader({required this.statusTop});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: statusTop + VailTheme.sm, left: VailTheme.lg, right: VailTheme.lg, bottom: VailTheme.sm),
      decoration: BoxDecoration(color: VailTheme.background.withValues(alpha: 0.95), border: const Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
      child: Row(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.eco_rounded, color: VailTheme.primary, size: 20), const SizedBox(width: 6), Text('Vail AI', style: VailTheme.heading.copyWith(color: VailTheme.primary, fontSize: 18))]),
          const Spacer(),
          Selector<ChatViewModel, String>(selector: (_, vm) => vm.activeModel, builder: (context, model, _) => _ModelSegmentedPill(activeModel: model)),
          const SizedBox(width: VailTheme.sm),
          GestureDetector(
            onTap: () => context.read<ChatViewModel>().startNewSession(),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: VailTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                border: Border.all(color: VailTheme.ghostBorder),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.edit_outlined, size: 15, color: VailTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSegmentedPill extends StatelessWidget {
  final String activeModel;
  const _ModelSegmentedPill({required this.activeModel});
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
          child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: VailTheme.md, vertical: VailTheme.xs + 1), decoration: BoxDecoration(color: t.$1 == activeModel ? VailTheme.primary.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(VailTheme.radiusFull)), child: Text(t.$2, style: VailTheme.caption.copyWith(color: t.$1 == activeModel ? VailTheme.primary : VailTheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10))),
        )).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(VailTheme.xxl), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: VailTheme.primaryContainer, shape: BoxShape.circle, border: Border.all(color: VailTheme.primary.withValues(alpha: 0.25)), boxShadow: VailTheme.aiCardGlow), child: const Icon(Icons.auto_awesome_rounded, color: VailTheme.primary, size: 28)),
      const SizedBox(height: VailTheme.lg),
      Text('Vail AI', style: VailTheme.display.copyWith(color: VailTheme.primary)),
      const SizedBox(height: VailTheme.xxl),
      Text('How can I help you today?', style: VailTheme.subheading, textAlign: TextAlign.center),
    ])));
  }
}
