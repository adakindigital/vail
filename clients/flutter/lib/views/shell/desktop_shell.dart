import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/services/vail_client.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';

/// Minimum screen width that activates the desktop layout.
const kDesktopBreakpoint = 720.0;

const _kSidebarWidth = 220.0;

/// Desktop two-panel layout: fixed sidebar + content area.
///
/// The [contentStack] is an [IndexedStack] of all app views, shared with the
/// mobile shell. The sidebar owns navigation, branding, and recent sessions.
/// The content area owns the top bar, view content, and chat status bar.
class DesktopShell extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onSwitch;

  /// The shared IndexedStack of app views — passed in from AppShell so the
  /// widget tree (and its state) is never recreated on layout changes.
  final Widget contentStack;

  const DesktopShell({
    required this.activeIndex,
    required this.onSwitch,
    required this.contentStack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Row(
        children: [
          SizedBox(
            width: _kSidebarWidth,
            child: _Sidebar(activeIndex: activeIndex, onSwitch: onSwitch),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: VailTheme.border),
          Expanded(
            child: Column(
              children: [
                _TopBar(activeIndex: activeIndex),
                Expanded(child: contentStack),
                if (activeIndex == 0) const _StatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatefulWidget {
  final int activeIndex;
  final void Function(int) onSwitch;

  const _Sidebar({required this.activeIndex, required this.onSwitch});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  @override
  void initState() {
    super.initState();
    // Load sessions so the recent sessions section is populated immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionsViewModel>().load();
    });
  }

  Future<void> _openSession(String sessionId) async {
    final config = GetIt.I<AppConfig>();
    final client = VailClient(
      endpoint: config.endpoint,
      apiKey: config.apiKey,
      sessionId: '',
    );
    try {
      final messages = await client.getSessionMessages(sessionId);
      if (!mounted) return;
      context.read<ChatViewModel>().loadSession(sessionId, messages);
    } catch (_) {}
    if (mounted) widget.onSwitch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VailTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarBrand(),
          const SizedBox(height: VailTheme.sm),
          _NewChatButton(
            onTap: () {
              context.read<ChatViewModel>().startNewSession();
              widget.onSwitch(0);
            },
          ),
          const SizedBox(height: VailTheme.sm),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'CHAT',
            isActive: widget.activeIndex == 0,
            onTap: () => widget.onSwitch(0),
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: 'HISTORY',
            isActive: widget.activeIndex == 1,
            onTap: () => widget.onSwitch(1),
          ),
          _NavItem(
            icon: Icons.insert_drive_file_outlined,
            label: 'LIBRARY',
            isActive: widget.activeIndex == 2,
            onTap: () => widget.onSwitch(2),
          ),
          const SizedBox(height: VailTheme.md),
          const Divider(height: 1, color: VailTheme.border),
          const SizedBox(height: VailTheme.md),
          _RecentSessionsSection(onOpenSession: _openSession),
          const Spacer(),
          const Divider(height: 1, color: VailTheme.border),
          _UpgradeBanner(),
          const Divider(height: 1, color: VailTheme.border),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'SETTINGS',
            isActive: widget.activeIndex == 3,
            onTap: () => widget.onSwitch(3),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar brand header ──────────────────────────────────────────────────────

class _SidebarBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(
        top: top + VailTheme.lg,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: VailTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: VailTheme.sm),
              Text(
                'VAIL',
                style: VailTheme.mono.copyWith(
                  color: VailTheme.textPrimary,
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'v${AppConstants.appVersion}  ·  STABLE',
            style: VailTheme.mono.copyWith(
              color: VailTheme.textMuted,
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New chat button ───────────────────────────────────────────────────────────

class _NewChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NewChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.md),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm + 2,
          ),
          decoration: BoxDecoration(
            color: VailTheme.accent,
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: VailTheme.onAccent, size: 14),
              const SizedBox(width: VailTheme.xs),
              Text(
                'NEW CHAT',
                style: VailTheme.mono.copyWith(
                  color: VailTheme.onAccent,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isActive ? VailTheme.accentSubtle : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? VailTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? VailTheme.accent : VailTheme.textSecondary,
            ),
            const SizedBox(width: VailTheme.md),
            Text(
              label,
              style: VailTheme.mono.copyWith(
                color: isActive ? VailTheme.accent : VailTheme.textSecondary,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent sessions section ───────────────────────────────────────────────────

class _RecentSessionsSection extends StatelessWidget {
  final Future<void> Function(String sessionId) onOpenSession;

  const _RecentSessionsSection({required this.onOpenSession});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SessionsViewModel>();
    final sessions = vm.sessions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.lg,
            vertical: VailTheme.xs,
          ),
          child: Text(
            'RECENT SESSIONS',
            style: VailTheme.mono.copyWith(
              color: VailTheme.textMuted,
              fontSize: 8,
              letterSpacing: 2,
            ),
          ),
        ),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.lg,
              vertical: VailTheme.sm,
            ),
            child: Text(
              'No sessions yet',
              style: VailTheme.mono.copyWith(
                color: VailTheme.textMuted,
                fontSize: 9,
              ),
            ),
          )
        else
          for (final session in sessions)
            _RecentSessionItem(
              session: session,
              onTap: () => onOpenSession(session.id),
            ),
      ],
    );
  }
}

class _RecentSessionItem extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;

  const _RecentSessionItem({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: VailTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: VailTheme.sm),
            Expanded(
              child: Text(
                session.displayTitle,
                style: VailTheme.mono.copyWith(
                  color: VailTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upgrade banner ────────────────────────────────────────────────────────────

class _UpgradeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VailTheme.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.md,
          vertical: VailTheme.sm + 2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: VailTheme.accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          gradient: const LinearGradient(
            colors: [
              VailTheme.accentSubtle,
              VailTheme.background,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: VailTheme.accent, size: 12),
            const SizedBox(width: VailTheme.xs),
            Text(
              'UPGRADE TO PRO',
              style: VailTheme.mono.copyWith(
                color: VailTheme.accent,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar (right panel header) ──────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  final int activeIndex;

  const _TopBar({required this.activeIndex});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  static const _titles = ['CHAT', 'HISTORY', 'LIBRARY', 'SETTINGS'];

  OverlayEntry? _pickerEntry;
  final _chipKey = GlobalKey();

  @override
  void dispose() {
    _dismissPicker();
    super.dispose();
  }

  // ── Model picker ────────────────────────────────────────────────────────────

  void _openModelPicker(String activeModel) {
    _dismissPicker();

    final box = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final vm = context.read<ChatViewModel>();

    _pickerEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Transparent backdrop — tap outside dismisses
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissPicker,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // Dropdown card
          Positioned(
            top: offset.dy + box.size.height + 4,
            right: VailTheme.lg,
            child: Material(
              color: Colors.transparent,
              child: _ModelPickerDropdown(
                activeModel: activeModel,
                onSelect: (model) {
                  vm.setModel(model);
                  _dismissPicker();
                },
                onUpgradeRequired: (tier) {
                  _dismissPicker();
                  _showUpgradeDialog(tier);
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_pickerEntry!);
  }

  void _dismissPicker() {
    _pickerEntry?.remove();
    _pickerEntry = null;
  }

  Future<void> _showUpgradeDialog(String tier) async {
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
    if (proceed == true && mounted) showUpgradeSheet(context);
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          Text(
            'VAIL  /  ${_titles[widget.activeIndex.clamp(0, 3)]}',
            style: VailTheme.mono.copyWith(
              color: VailTheme.textMuted,
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          // Model chip + tier badge (chat only)
          if (widget.activeIndex == 0)
            Selector<ChatViewModel, String>(
              selector: (_, vm) => vm.activeModel,
              builder: (_, model, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: _chipKey,
                    onTap: () => _openModelPicker(model),
                    child: _DesktopModelChip(model: model),
                  ),
                  const SizedBox(width: VailTheme.sm),
                  const _DesktopTierBadge(isPro: false), // TODO: real tier
                ],
              ),
            ),
          const SizedBox(width: VailTheme.sm),
          // Gateway status dot
          _GatewayDot(),
        ],
      ),
    );
  }
}

// ── Desktop model chip ────────────────────────────────────────────────────────

class _DesktopModelChip extends StatelessWidget {
  final String model;

  const _DesktopModelChip({required this.model});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.sm + 2,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: VailTheme.accentSubtle,
          border: Border.all(
            color: VailTheme.accent.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(4),
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
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: VailTheme.accent,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop tier badge ────────────────────────────────────────────────────────

class _DesktopTierBadge extends StatelessWidget {
  final bool isPro;

  const _DesktopTierBadge({required this.isPro});

  @override
  Widget build(BuildContext context) {
    const proColor = Color(0xFFE5C07B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: 2),
      decoration: BoxDecoration(
        color: isPro ? proColor.withValues(alpha: 0.08) : Colors.transparent,
        border: Border.all(
          color: isPro ? proColor.withValues(alpha: 0.45) : VailTheme.border,
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

// ── Desktop model picker dropdown ─────────────────────────────────────────────

class _ModelPickerDropdown extends StatelessWidget {
  final String activeModel;
  final void Function(String) onSelect;
  final void Function(String) onUpgradeRequired;

  const _ModelPickerDropdown({
    required this.activeModel,
    required this.onSelect,
    required this.onUpgradeRequired,
  });

  static const _freeTiers = ['vail-lite', 'vail'];
  static const _proTiers = ['vail-pro', 'vail-max'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: VailTheme.surface,
        border: Border.all(color: VailTheme.border),
        borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.md, VailTheme.md, VailTheme.md, VailTheme.sm,
            ),
            child: Row(
              children: [
                Text('SELECT MODEL', style: VailTheme.sectionLabel),
                const Spacer(),
                const _DesktopTierBadge(isPro: false), // TODO: user tier
              ],
            ),
          ),
          const Divider(height: 1, color: VailTheme.border),
          // Free tier
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.md, VailTheme.md, VailTheme.md, VailTheme.xs,
            ),
            child: Text(
              'FREE TIER',
              style: VailTheme.mono
                  .copyWith(color: VailTheme.textMuted, fontSize: 9),
            ),
          ),
          for (final tier in _freeTiers)
            _DesktopPickerRow(
              tier: tier,
              isActive: tier == activeModel,
              isPremium: false,
              onTap: () => onSelect(tier),
            ),
          // Pro tier
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.md, VailTheme.md, VailTheme.md, VailTheme.xs,
            ),
            child: Row(
              children: [
                Text(
                  'PRO TIER',
                  style: VailTheme.mono
                      .copyWith(color: VailTheme.textMuted, fontSize: 9),
                ),
                const SizedBox(width: VailTheme.sm),
                _DesktopUpgradeTag(),
              ],
            ),
          ),
          for (final tier in _proTiers)
            _DesktopPickerRow(
              tier: tier,
              isActive: tier == activeModel,
              isPremium: true,
              isComingSoon: AppConstants.isComingSoonTier(tier),
              onTap: AppConstants.isComingSoonTier(tier)
                  ? () {}
                  : () => onUpgradeRequired(tier),
            ),
          const SizedBox(height: VailTheme.sm),
        ],
      ),
    );
  }
}

class _DesktopUpgradeTag extends StatelessWidget {
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

class _DesktopPickerRow extends StatelessWidget {
  final String tier;
  final bool isActive;
  final bool isPremium;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _DesktopPickerRow({
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

    return MouseRegion(
      cursor: isComingSoon
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm + 2,
          ),
          color: isActive ? VailTheme.accentSubtle : Colors.transparent,
          child: Row(
            children: [
              Container(
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
                            fontSize: 10,
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
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_rounded,
                    color: VailTheme.accent, size: 13)
              else if (isComingSoon)
                const Icon(Icons.schedule_rounded,
                    color: soonColor, size: 13)
              else if (isPremium)
                const Icon(Icons.lock_outline_rounded,
                    color: proColor, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: VailTheme.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Status bar (chat only) ────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
      decoration: const BoxDecoration(
        color: VailTheme.surface,
        border: Border(top: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 9, color: VailTheme.accent),
          const SizedBox(width: VailTheme.xs),
          Text(
            'ENCRYPTION: AES-256 ENABLED',
            style: VailTheme.mono.copyWith(
              color: VailTheme.accent,
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Selector<ChatViewModel, int>(
            selector: (context, vm) => vm.messages.length,
            builder: (context, count, child) => Text(
              '$count MESSAGES  ·  SESSION ACTIVE',
              style: VailTheme.mono.copyWith(
                color: VailTheme.textMuted,
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
