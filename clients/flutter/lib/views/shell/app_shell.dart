import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/platform/responsive.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/chat/chat_view.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/documents/documents_view.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_view.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';
import 'package:vail_app/views/settings/settings_view.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';
import 'package:vail_app/views/shell/desktop_shell.dart';

/// Root shell — holds all ViewModels for the lifetime of the app.
///
/// Mobile: tab-based layout with a glassmorphic Forest Sanctuary bottom nav.
/// Desktop: [DesktopShell] with sidebar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _activeIndex = 0;

  void _switchTo(int index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ChangeNotifierProvider(create: (_) => SessionsViewModel()),
        ChangeNotifierProvider(create: (_) => DocumentsViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
      ],
      child: Builder(
        builder: (context) {
          final stack = IndexedStack(
            index: _activeIndex,
            children: [
              ChatView(onSwitchTab: _switchTo),
              SessionsView(onSwitchTab: _switchTo),
              const DocumentsView(),
              const SettingsView(),
            ],
          );

          if (Responsive.isDesktop(context)) {
            return DesktopShell(
              activeIndex: _activeIndex,
              onSwitch: _switchTo,
              contentStack: stack,
            );
          }

          return _MobileShell(
            activeIndex: _activeIndex,
            onSwitch: _switchTo,
            contentStack: stack,
          );
        },
      ),
    );
  }
}

// ── Mobile shell ──────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onSwitch;
  final Widget contentStack;

  const _MobileShell({
    required this.activeIndex,
    required this.onSwitch,
    required this.contentStack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: contentStack,
      extendBody: true,
      bottomNavigationBar: _ForestBottomNav(
        activeIndex: activeIndex,
        onTap: onSwitch,
      ),
    );
  }
}

// ── Forest Sanctuary bottom nav ───────────────────────────────────────────────

class _ForestBottomNav extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;

  const _ForestBottomNav({
    required this.activeIndex,
    required this.onTap,
  });

  static const _items = [
    (
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    (
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    (
      icon: Icons.description_outlined,
      activeIcon: Icons.description_rounded,
      label: 'Docs',
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: VailTheme.background.withValues(alpha: 0.95),
            border: const Border(
              top: BorderSide(color: VailTheme.ghostBorder),
            ),
            boxShadow: [
              BoxShadow(
                color: VailTheme.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: VailTheme.sm,
            bottom: bottomPad > 0 ? bottomPad : VailTheme.md,
          ),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].icon,
                    activeIcon: _items[i].activeIcon,
                    label: _items[i].label,
                    isActive: activeIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: VailTheme.xs + 1,
          horizontal: VailTheme.md,
        ),
        decoration: isActive
            ? BoxDecoration(
                color: VailTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? VailTheme.primary
                  : VailTheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: VailTheme.caption.copyWith(
                color: isActive
                    ? VailTheme.primary
                    : VailTheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
