import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';
import 'package:vail_app/views/settings/widgets/usage_card.dart';

class SettingsViewDesktop extends StatelessWidget {
  const SettingsViewDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — configuration
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VailTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('API CONFIGURATION'),
                const SizedBox(height: VailTheme.md),
                const _ApiKeyField(),
                const SizedBox(height: VailTheme.sm),
                const _EndpointField(),
                const SizedBox(height: VailTheme.xxl),
                const _SectionLabel('BILLING'),
                const SizedBox(height: VailTheme.md),
                const _ProPlanToggle(),
                const SizedBox(height: VailTheme.xxl),
                const _SectionLabel('MODEL SELECTION'),
                const SizedBox(height: VailTheme.md),
                const _ModelPills(),
                const SizedBox(height: VailTheme.xxl),
                const _SectionLabel('INTERFACE PREFERENCES'),
                const SizedBox(height: VailTheme.md),
                const _VisualModeRow(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: VailTheme.ghostBorder),
        // Right column — status and about
        const SizedBox(
          width: 320,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(VailTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UsageCard(),
                SizedBox(height: VailTheme.xxl),
                _SectionLabel('ABOUT'),
                SizedBox(height: VailTheme.md),
                _AboutCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: VailTheme.caption);
}

class _ApiKeyField extends StatefulWidget {
  const _ApiKeyField();
  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SettingsViewModel>().apiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API KEY', style: VailTheme.micro),
        const SizedBox(height: VailTheme.sm),
        _DarkTextField(
          controller: _controller,
          obscureText: _obscure,
          hintText: 'sk-vail-••••••••',
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: VailTheme.onSurfaceVariant, size: 18),
          ),
          onSubmitted: (v) => context.read<SettingsViewModel>().saveApiKey(v),
        ),
      ],
    );
  }
}

class _EndpointField extends StatefulWidget {
  const _EndpointField();
  @override
  State<_EndpointField> createState() => _EndpointFieldState();
}

class _EndpointFieldState extends State<_EndpointField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SettingsViewModel>().endpoint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ENDPOINT', style: VailTheme.micro),
        const SizedBox(height: VailTheme.sm),
        _DarkTextField(
          controller: _controller,
          hintText: 'http://localhost:9090',
          onSubmitted: (v) => context.read<SettingsViewModel>().saveEndpoint(v),
        ),
      ],
    );
  }
}

class _ModelPills extends StatelessWidget {
  const _ModelPills();

  Future<void> _onPillTap(BuildContext context, String model) async {
    if (AppConstants.isPremiumTier(model)) {
      await _showUpgradeDialog(context, model);
      return;
    }
    if (!context.mounted) return;
    context.read<SettingsViewModel>().selectModel(model);
    context.read<ChatViewModel>().setModel(model);
  }

  Future<void> _showUpgradeDialog(BuildContext context, String tier) async {
    final features = _premiumFeatures(tier);
    await showVailDialog<void>(
      context: context,
      title: 'UPGRADE REQUIRED',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: 2),
                decoration: BoxDecoration(color: VailTheme.primaryContainer, border: Border.all(color: VailTheme.primary.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(3)),
                child: Text(AppConstants.modelDisplayName(tier), style: VailTheme.micro.copyWith(color: VailTheme.primary)),
              ),
              const SizedBox(width: VailTheme.sm),
              Text('PRO PLAN', style: VailTheme.micro),
            ],
          ),
          const SizedBox(height: VailTheme.md),
          Text(AppConstants.modelDescription(tier), style: VailTheme.bodySmall),
          const SizedBox(height: VailTheme.md),
          const Divider(height: 1, color: VailTheme.ghostBorder),
          const SizedBox(height: VailTheme.md),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: VailTheme.sm),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, color: VailTheme.primary, size: 12),
                  const SizedBox(width: VailTheme.sm),
                  Text(feature, style: VailTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
      actions: const [
        VailDialogAction(label: 'CANCEL', value: null),
        VailDialogAction(label: 'UPGRADE', value: null, isPrimary: true),
      ],
    );
  }

  List<String> _premiumFeatures(String tier) => switch (tier) {
        'vail-pro' => ['Extended context window', 'Priority routing', 'Complex multi-step reasoning', 'Faster response times'],
        'vail-max' => ['Maximum reasoning capability', 'Largest context window', 'Dedicated compute allocation', 'Enterprise-grade SLA'],
        _ => ['Advanced capabilities'],
      };

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<SettingsViewModel>().selectedModel;
    final models = context.read<SettingsViewModel>().availableModels;

    return Wrap(
      spacing: VailTheme.sm,
      runSpacing: VailTheme.sm,
      children: models.map((model) {
        final isActive = model == selected;
        final isPremium = AppConstants.isPremiumTier(model);
        return _ModelPill(
          label: AppConstants.modelDisplayName(model),
          isActive: isActive,
          isPremium: isPremium,
          onTap: () => _onPillTap(context, model),
        );
      }).toList(),
    );
  }
}

class _ModelPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isPremium;
  final VoidCallback onTap;

  const _ModelPill({required this.label, required this.isActive, required this.isPremium, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? VailTheme.primary : (isPremium ? VailTheme.textMuted : VailTheme.onSurfaceVariant);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.sm),
        decoration: BoxDecoration(
          color: isActive ? VailTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: isActive ? VailTheme.primary : VailTheme.ghostBorder),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium) ...[Icon(Icons.lock_outline_rounded, color: color, size: 10), const SizedBox(width: VailTheme.xs)],
            Text(label, style: VailTheme.micro.copyWith(color: color, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _VisualModeRow extends StatelessWidget {
  const _VisualModeRow();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VailTheme.md),
      decoration: BoxDecoration(color: VailTheme.surfaceContainerLow.withValues(alpha: 0.4), border: Border.all(color: VailTheme.ghostBorder), borderRadius: BorderRadius.circular(VailTheme.radiusMd)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visual Mode', style: VailTheme.label),
                Text('Toggle between dark and light interface.', style: VailTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(value: false, onChanged: null),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VailTheme.lg),
      decoration: BoxDecoration(color: VailTheme.surfaceContainer.withValues(alpha: 0.3), border: Border.all(color: VailTheme.ghostBorder), borderRadius: BorderRadius.circular(VailTheme.radiusMd)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('VAIL', style: VailTheme.micro.copyWith(color: VailTheme.primary, fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w700)),
              const SizedBox(width: VailTheme.sm),
              Container(padding: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: 2), decoration: BoxDecoration(border: Border.all(color: VailTheme.ghostBorder), borderRadius: BorderRadius.circular(3)), child: const Text('v0.1.0', style: TextStyle(fontSize: 8))),
            ],
          ),
          const SizedBox(height: VailTheme.md),
          const _AboutRow(label: 'ENGINE', value: 'VAIL INTELLIGENCE ENGINE'),
          const _AboutRow(label: 'DOMAIN', value: 'vail.adakindigital.com'),
          const SizedBox(height: VailTheme.md),
          const Divider(height: 1, color: VailTheme.ghostBorder),
          const SizedBox(height: VailTheme.md),
          Text('"He who dwells in the secret place of the Most High\nshall abide under the shadow of the Almighty."', style: VailTheme.micro.copyWith(fontStyle: FontStyle.italic, height: 1.6)),
          const SizedBox(height: 4),
          const Text('Psalm 91:1', style: TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [SizedBox(width: 60, child: Text(label, style: VailTheme.micro)), Expanded(child: Text(value, style: VailTheme.bodySmall.copyWith(fontSize: 10)))]));
}

class _ProPlanToggle extends StatelessWidget {
  const _ProPlanToggle();
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Container(
      padding: const EdgeInsets.all(VailTheme.md),
      decoration: BoxDecoration(color: VailTheme.surfaceContainerLow.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(VailTheme.radiusMd), border: Border.all(color: VailTheme.ghostBorder)),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 18, color: VailTheme.primary),
          const SizedBox(width: VailTheme.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PRO PLAN', style: VailTheme.label.copyWith(color: VailTheme.primary, fontWeight: FontWeight.w700)), Text('Unlock advanced reasoning', style: VailTheme.bodySmall)])),
          Switch.adaptive(value: vm.isPro, onChanged: (v) => vm.setIsPro(v), activeTrackColor: VailTheme.primary),
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final void Function(String)? onSubmitted;
  const _DarkTextField({required this.controller, required this.hintText, this.obscureText = false, this.suffix, this.onSubmitted});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), border: Border.all(color: VailTheme.ghostBorder), borderRadius: BorderRadius.circular(VailTheme.radiusSm)), child: TextField(controller: controller, obscureText: obscureText, style: VailTheme.bodySmall, onSubmitted: onSubmitted, decoration: InputDecoration(hintText: hintText, hintStyle: TextStyle(color: VailTheme.onSurfaceVariant.withValues(alpha: 0.3)), suffixIcon: suffix, border: InputBorder.none, contentPadding: const EdgeInsets.all(VailTheme.md))));
}
