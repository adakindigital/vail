import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';

const _kSidebarWidth = 256.0;

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
          Container(width: 1, color: VailTheme.ghostBorder),
          Expanded(
            child: Column(
              children: [
                if (activeIndex != 0) _SectionTopBar(activeIndex: activeIndex, onSwitch: onSwitch),
                Expanded(child: contentStack),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: VailTheme.background,
      padding: EdgeInsets.only(top: topPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.xl),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: VailTheme.primary, borderRadius: BorderRadius.circular(VailTheme.radiusSm - 4)),
                  child: const Icon(Icons.park_rounded, color: VailTheme.onPrimary, size: 16),
                ),
                const SizedBox(width: VailTheme.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vail AI', style: VailTheme.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('BY ADAKIN DIGITAL', style: VailTheme.micro.copyWith(fontSize: 8, letterSpacing: 1.2)),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.sm),
            child: _NewChatButton(onTap: () {
              context.read<ChatViewModel>().startNewSession();
              widget.onSwitch(0);
            }),
          ),
          const SizedBox(height: VailTheme.md),
          _SidebarNavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy_rounded, label: 'Assistant', isActive: widget.activeIndex == 0, onTap: () => widget.onSwitch(0)),
          _SidebarNavItem(icon: Icons.history_rounded, label: 'History', isActive: widget.activeIndex == 2, onTap: () => widget.onSwitch(2)),
          _SidebarNavItem(icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, label: 'Library', isActive: widget.activeIndex == 1, onTap: () => widget.onSwitch(1)),
          _SidebarNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics', isActive: widget.activeIndex == 3, onTap: () => widget.onSwitch(3)),
          const Spacer(),
          _SidebarNavItem(icon: Icons.help_outline_rounded, label: 'Help', onTap: () {}),
          _SidebarNavItem(icon: Icons.logout_rounded, label: 'Sign Out', onTap: () {}),
          const SizedBox(height: VailTheme.xl),
        ],
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
        height: 48,
        decoration: BoxDecoration(color: VailTheme.primary, borderRadius: BorderRadius.circular(VailTheme.radiusFull), boxShadow: VailTheme.primaryGlow),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, color: VailTheme.onPrimary, size: 20), SizedBox(width: 8), Text('New Chat', style: TextStyle(color: VailTheme.onPrimary, fontWeight: FontWeight.w700))]),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _SidebarNavItem({required this.icon, this.activeIcon, required this.label, this.isActive = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: VailTheme.md, vertical: 12),
        decoration: isActive ? BoxDecoration(color: VailTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(VailTheme.radiusSm), border: Border.all(color: VailTheme.primary.withValues(alpha: 0.15))) : null,
        child: Row(children: [
          Icon(isActive ? (activeIcon ?? icon) : icon, size: 20, color: isActive ? VailTheme.primary : VailTheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: isActive ? VailTheme.primary : VailTheme.onSurfaceVariant.withValues(alpha: 0.8), fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _SectionTopBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onSwitch;
  const _SectionTopBar({required this.activeIndex, required this.onSwitch});
  static const _titles = {0: 'Assistant', 1: 'Library', 2: 'History', 3: 'Settings'};
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.xl),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
      child: Row(children: [
        Text(_titles[activeIndex] ?? 'Section', style: VailTheme.heading.copyWith(fontSize: 18)),
        const Spacer(),
        IconButton(onPressed: () => onSwitch(3), icon: const Icon(Icons.settings_outlined)),
        const SizedBox(width: 12),
        const CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=vail')),
      ]),
    );
  }
}
