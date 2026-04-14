import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/services/vail_client.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';

const kDesktopBreakpoint = 720.0;
const _kSidebarWidth = 256.0;

/// Desktop two-panel layout: Forest Sanctuary sidebar + content area.
class DesktopShell extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onSwitch;
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
          // Subtle separator — no VerticalDivider, use ghost border
          Container(width: 1, color: VailTheme.ghostBorder),
          Expanded(
            child: Column(
              children: [
                // Chat has its own top bar — skip for that tab
                if (activeIndex != 0) _SectionTopBar(activeIndex: activeIndex),
                Expanded(child: contentStack),
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
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: VailTheme.background,
      padding: EdgeInsets.only(top: topPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.xl,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: VailTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                    border: Border.all(
                      color: VailTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: VailTheme.primary,
                    size: 20,
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
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Forest Sanctuary',
                      style: VailTheme.caption.copyWith(
                        color: VailTheme.onSurfaceVariant.withValues(alpha: 0.4),
                        letterSpacing: 1.5,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Nav items
          _SidebarNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Chat',
            isActive: widget.activeIndex == 0,
            onTap: () => widget.onSwitch(0),
          ),
          _SidebarNavItem(
            icon: Icons.history_rounded,
            activeIcon: Icons.history_rounded,
            label: 'History',
            isActive: widget.activeIndex == 1,
            onTap: () => widget.onSwitch(1),
          ),
          _SidebarNavItem(
            icon: Icons.description_outlined,
            activeIcon: Icons.description_rounded,
            label: 'Docs',
            isActive: widget.activeIndex == 2,
            onTap: () => widget.onSwitch(2),
          ),
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
            isActive: widget.activeIndex == 3,
            onTap: () => widget.onSwitch(3),
          ),
          const SizedBox(height: VailTheme.lg),
          // Recent sessions
          _RecentSessionsSection(onOpenSession: _openSession),
          const Spacer(),
          // Upgrade Plan CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg),
            child: GestureDetector(
              onTap: () => showUpgradeSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: VailTheme.md + 2,
                ),
                decoration: BoxDecoration(
                  color: VailTheme.primary,
                  borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                  boxShadow: VailTheme.primaryGlow,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Upgrade Plan',
                  style: VailTheme.label.copyWith(
                    color: VailTheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          // User card
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.xl,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: VailTheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: VailTheme.ghostBorder),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: VailTheme.onSurfaceVariant,
                    size: 16,
                  ),
                ),
                const SizedBox(width: VailTheme.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Plan',
                        style: VailTheme.caption.copyWith(
                          color: VailTheme.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 9,
                        ),
                      ),
                    ],
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

// ── Sidebar nav item ──────────────────────────────────────────────────────────

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
            horizontal: VailTheme.sm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? VailTheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
            border: isActive
                ? Border.all(
                    color: VailTheme.primary.withValues(alpha: 0.15),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 18,
                color: isActive
                    ? VailTheme.primary
                    : VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: VailTheme.md),
              Text(
                label,
                style: VailTheme.label.copyWith(
                  color: isActive
                      ? VailTheme.primary
                      : VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.fromLTRB(
            VailTheme.lg, 0, VailTheme.lg, VailTheme.sm,
          ),
          child: Text(
            'Recent',
            style: VailTheme.caption.copyWith(
              color: VailTheme.onSurfaceVariant.withValues(alpha: 0.35),
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.lg,
              vertical: VailTheme.xs,
            ),
            child: Text(
              'No sessions yet',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.textMuted,
                fontSize: 11,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: VailTheme.sm,
            vertical: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: VailTheme.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: VailTheme.sm),
              Expanded(
                child: Text(
                  session.displayTitle,
                  style: VailTheme.bodySmall.copyWith(
                    color: VailTheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section top bar (non-chat tabs) ──────────────────────────────────────────

class _SectionTopBar extends StatelessWidget {
  final int activeIndex;

  const _SectionTopBar({required this.activeIndex});

  static const _titles = ['Chat', 'History', 'Docs', 'Settings'];

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
          Text(
            _titles[activeIndex.clamp(0, 3)],
            style: VailTheme.heading.copyWith(fontSize: 16),
          ),
          const Spacer(),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: VailTheme.primary,
              shape: BoxShape.circle,
              boxShadow: VailTheme.primaryGlow,
            ),
          ),
        ],
      ),
    );
  }
}
