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
/// Uses [Responsive.isDesktop] to switch between layouts:
/// - Mobile : tab-based layout with bottom navigation bar.
/// - Desktop: sidebar + content area layout ([DesktopShell]).
///
/// The [IndexedStack] of views is created once per build and passed to
/// whichever layout is active — state is preserved on orientation and
/// window-resize changes via Flutter's widget reconciliation.
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
      bottomNavigationBar: _VailBottomNav(
        activeIndex: activeIndex,
        onTap: onSwitch,
      ),
    );
  }
}

// ── Bottom nav (mobile only) ──────────────────────────────────────────────────

class _VailBottomNav extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;

  const _VailBottomNav({
    required this.activeIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.chat_bubble_outline_rounded, label: 'CHAT'),
    (icon: Icons.history_rounded, label: 'HISTORY'),
    (icon: Icons.insert_drive_file_outlined, label: 'DOCS'),
    (icon: Icons.settings_outlined, label: 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VailTheme.surface,
        border: Border(top: BorderSide(color: VailTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].icon,
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
    final color = isActive ? VailTheme.accent : VailTheme.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: VailTheme.mono.copyWith(color: color)),
        ],
      ),
    );
  }
}
