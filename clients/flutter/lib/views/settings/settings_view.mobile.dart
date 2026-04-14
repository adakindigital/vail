import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';

/// Mobile settings UI — scrollable settings with status-bar-aware header.
///
/// Rendered by [SettingsView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [SettingsView].
class SettingsViewMobile extends StatelessWidget {
  const SettingsViewMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsHeader(statusTop: MediaQuery.of(context).padding.top),
        const Expanded(child: _SettingsBody()),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  final double statusTop;

  const _SettingsHeader({required this.statusTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: statusTop + VailTheme.lg,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.lg,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text('Settings', style: VailTheme.heading)),
          Text(
            'v${AppConstants.appVersion}',
            style: VailTheme.mono.copyWith(color: VailTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: VailTheme.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('API CONFIGURATION'),
          SizedBox(height: VailTheme.md),
          _ApiKeyField(),
          SizedBox(height: VailTheme.sm),
          _EndpointField(),
          SizedBox(height: VailTheme.xxl),
          _SectionLabel('MODEL SELECTION'),
          SizedBox(height: VailTheme.md),
          _ModelPills(),
          SizedBox(height: VailTheme.xxl),
          _SectionLabel('SYSTEM STATUS'),
          SizedBox(height: VailTheme.md),
          _GatewayStatusCard(),
          SizedBox(height: VailTheme.xxl),
          _SectionLabel('INTERFACE PREFERENCES'),
          SizedBox(height: VailTheme.md),
          _VisualModeRow(),
          SizedBox(height: VailTheme.xxl),
          _SectionLabel('ABOUT'),
          SizedBox(height: VailTheme.md),
          _AboutCard(),
          SizedBox(height: VailTheme.xl),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Text(text, style: VailTheme.sectionLabel),
    );
  }
}

// ── API key field ─────────────────────────────────────────────────────────────

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
    _controller = TextEditingController(
      text: context.read<SettingsViewModel>().apiKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('API KEY',
              style: VailTheme.mono.copyWith(color: VailTheme.textSecondary)),
          const SizedBox(height: VailTheme.sm),
          _DarkTextField(
            controller: _controller,
            obscureText: _obscure,
            hintText: 'sk-vail-••••••••',
            suffix: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: VailTheme.textSecondary,
                size: 18,
              ),
            ),
            onSubmitted: (v) =>
                context.read<SettingsViewModel>().saveApiKey(v),
          ),
        ],
      ),
    );
  }
}

// ── Endpoint field ────────────────────────────────────────────────────────────

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
    _controller = TextEditingController(
      text: context.read<SettingsViewModel>().endpoint,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENDPOINT',
              style: VailTheme.mono.copyWith(color: VailTheme.textSecondary)),
          const SizedBox(height: VailTheme.sm),
          _DarkTextField(
            controller: _controller,
            hintText: 'http://localhost:9090',
            onSubmitted: (v) =>
                context.read<SettingsViewModel>().saveEndpoint(v),
          ),
        ],
      ),
    );
  }
}

// ── Model pills ───────────────────────────────────────────────────────────────

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
                padding: const EdgeInsets.symmetric(
                  horizontal: VailTheme.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: VailTheme.accentSubtle,
                  border: Border.all(
                      color: VailTheme.accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  AppConstants.modelDisplayName(tier),
                  style: VailTheme.mono.copyWith(
                    color: VailTheme.accent,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: VailTheme.sm),
              Text(
                'PRO PLAN',
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
          // Feature list
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
        VailDialogAction(label: 'CANCEL', value: null),
        VailDialogAction(
          label: 'UPGRADE',
          value: null,
          isPrimary: true,
          // TODO: wire to payment gateway (Stripe/PayFast)
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<SettingsViewModel>().selectedModel;
    final models = context.read<SettingsViewModel>().availableModels;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Wrap(
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
      ),
    );
  }
}

class _ModelPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isPremium;
  final VoidCallback onTap;

  const _ModelPill({
    required this.label,
    required this.isActive,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isActive
        ? VailTheme.accent
        : isPremium
            ? VailTheme.textMuted
            : VailTheme.textSecondary;
    final borderColor = isActive
        ? VailTheme.accent
        : isPremium
            ? VailTheme.border.withValues(alpha: 0.5)
            : VailTheme.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? VailTheme.accentSubtle : Colors.transparent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium) ...[
              Icon(Icons.lock_outline_rounded, color: labelColor, size: 10),
              const SizedBox(width: VailTheme.xs),
            ],
            Text(
              label,
              style: VailTheme.mono.copyWith(
                color: labelColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gateway status card ───────────────────────────────────────────────────────

class _GatewayStatusCard extends StatelessWidget {
  const _GatewayStatusCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Container(
        padding: const EdgeInsets.all(VailTheme.lg),
        decoration: BoxDecoration(
          color: VailTheme.surface,
          border: Border.all(color: VailTheme.border),
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(status: vm.gatewayStatus),
                const SizedBox(width: VailTheme.sm),
                Expanded(
                  child: Text(
                    'GATEWAY',
                    style: VailTheme.mono.copyWith(
                      color: VailTheme.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  _statusLabel(vm.gatewayStatus),
                  style: VailTheme.mono.copyWith(
                    color: _statusColor(vm.gatewayStatus),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VailTheme.sm),
            Text(
              vm.endpoint,
              style: VailTheme.mono.copyWith(
                color: VailTheme.textSecondary,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: VailTheme.md),
            VailButton.ghost(
              label: vm.gatewayStatus == GatewayStatus.checking
                  ? 'CHECKING...'
                  : 'CHECK CONNECTION',
              onTap: vm.gatewayStatus == GatewayStatus.checking
                  ? null
                  : () => context.read<SettingsViewModel>().checkGateway(),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(GatewayStatus status) => switch (status) {
        GatewayStatus.unknown => 'UNKNOWN',
        GatewayStatus.checking => 'CHECKING',
        GatewayStatus.online => 'ONLINE',
        GatewayStatus.offline => 'OFFLINE',
      };

  Color _statusColor(GatewayStatus status) => switch (status) {
        GatewayStatus.unknown => VailTheme.textMuted,
        GatewayStatus.checking => const Color(0xFFE5C07B),
        GatewayStatus.online => VailTheme.accent,
        GatewayStatus.offline => VailTheme.error,
      };
}

class _StatusDot extends StatelessWidget {
  final GatewayStatus status;

  const _StatusDot({required this.status});

  Color get _color => switch (status) {
        GatewayStatus.unknown => VailTheme.textMuted,
        GatewayStatus.checking => const Color(0xFFE5C07B),
        GatewayStatus.online => VailTheme.accent,
        GatewayStatus.offline => VailTheme.error,
      };

  @override
  Widget build(BuildContext context) {
    if (status == GatewayStatus.checking) {
      return SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: _color),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}

// ── Visual mode ───────────────────────────────────────────────────────────────

class _VisualModeRow extends StatelessWidget {
  const _VisualModeRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.md,
        ),
        decoration: BoxDecoration(
          color: VailTheme.surface,
          border: Border.all(color: VailTheme.border),
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visual Mode', style: VailTheme.body),
                  const SizedBox(height: 2),
                  Text(
                    'Toggle between dark and light interface.',
                    style: VailTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: false, // Dark-only in v1 — light mode is Phase 3
              onChanged: null,
              activeThumbColor: VailTheme.accent,
              inactiveThumbColor: VailTheme.textMuted,
              inactiveTrackColor: VailTheme.border,
            ),
          ],
        ),
      ),
    );
  }
}

// ── About card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VailTheme.lg),
        decoration: BoxDecoration(
          color: VailTheme.surface,
          border: Border.all(color: VailTheme.border),
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'VAIL',
                  style: VailTheme.mono.copyWith(
                    color: VailTheme.accent,
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: VailTheme.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VailTheme.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: VailTheme.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'v${AppConstants.appVersion}',
                    style: VailTheme.mono
                        .copyWith(color: VailTheme.textMuted, fontSize: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VailTheme.sm),
            Text(
              'Versatile Artificial Intelligence Layer',
              style:
                  VailTheme.bodySmall.copyWith(color: VailTheme.textSecondary),
            ),
            const SizedBox(height: VailTheme.md),
            const Divider(height: 1, color: VailTheme.border),
            const SizedBox(height: VailTheme.md),
            const _AboutRow(label: 'PHASE', value: AppConstants.buildPhase),
            const SizedBox(height: VailTheme.xs + 2),
            const _AboutRow(
                label: 'ENGINE', value: 'VAIL INTELLIGENCE ENGINE'),
            const SizedBox(height: VailTheme.xs + 2),
            const _AboutRow(
                label: 'DOMAIN', value: 'vail.adakindigital.com'),
            const SizedBox(height: VailTheme.md),
            const Divider(height: 1, color: VailTheme.border),
            const SizedBox(height: VailTheme.md),
            Text(
              '"He who dwells in the secret place of the Most High\nshall abide under the shadow of the Almighty."',
              style: VailTheme.mono.copyWith(
                color: VailTheme.textMuted,
                fontSize: 9,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
            const SizedBox(height: VailTheme.xs),
            Text(
              'Psalm 91:1',
              style:
                  VailTheme.mono.copyWith(color: VailTheme.textMuted, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: VailTheme.mono
                .copyWith(color: VailTheme.textMuted, fontSize: 9),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: VailTheme.mono
                .copyWith(color: VailTheme.textSecondary, fontSize: 9),
          ),
        ),
      ],
    );
  }
}

// ── Shared: dark text field ───────────────────────────────────────────────────

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final void Function(String)? onSubmitted;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VailTheme.surfaceInput,
        border: Border.all(color: VailTheme.border),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: VailTheme.body,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: VailTheme.body.copyWith(color: VailTheme.textMuted),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: VailTheme.md),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.md,
          ),
        ),
      ),
    );
  }
}
