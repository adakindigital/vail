import 'package:flutter/material.dart';
import 'package:vail_app/core/platform/responsive.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';

class SessionsEmptyState extends StatelessWidget {
  final VoidCallback onStartChat;

  const SessionsEmptyState({required this.onStartChat, super.key});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return _DesktopEmptyState(onStartChat: onStartChat);
    }
    return _MobileEmptyState(onStartChat: onStartChat);
  }
}

class _DesktopEmptyState extends StatelessWidget {
  final VoidCallback onStartChat;
  const _DesktopEmptyState({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VailTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(VailTheme.radiusXl),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=800&q=80',
                    width: 400,
                    height: 400,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 80,
                  right: 100,
                  child: _GlassBadge(label: 'ORGANIC SYNC', icon: Icons.eco_rounded),
                ),
                Positioned(
                  bottom: 120,
                  left: 80,
                  child: _GlassBadge(label: 'ROOTED AI', icon: Icons.auto_awesome_rounded),
                ),
              ],
            ),
            const SizedBox(height: VailTheme.xxl),
            Text(
              'Silence in the Canopy',
              style: VailTheme.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.md),
            Text(
              'Your conversations will appear here once you start chatting with Vail.',
              style: VailTheme.body.copyWith(color: VailTheme.onSurfaceVariant.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xxl),
            SizedBox(
              width: 240,
              child: VailButton.primary(
                label: 'Start New Chat',
                leadingIcon: Icons.chat_bubble_rounded,
                onTap: onStartChat,
              ),
            ),
            const SizedBox(height: 64),
            const Wrap(
              spacing: VailTheme.lg,
              runSpacing: VailTheme.lg,
              alignment: WrapAlignment.center,
              children: [
                _FeatureCard(
                  title: 'Personalized Growth',
                  desc: 'Vail adapts to your cognitive style with every interaction.',
                  icon: Icons.auto_awesome_rounded,
                ),
                _FeatureCard(
                  title: 'Secure Root System',
                  desc: 'End-to-end encrypted neural pathways for your data.',
                  icon: Icons.shield_outlined,
                ),
                _FeatureCard(
                  title: 'Deep Connections',
                  desc: 'Link your workspace nodes for integrated intelligence.',
                  icon: Icons.hub_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileEmptyState extends StatelessWidget {
  final VoidCallback onStartChat;
  const _MobileEmptyState({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.xl, vertical: VailTheme.xxl),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(VailTheme.radiusXl),
                child: Image.network(
                  'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=600&q=80',
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VailTheme.radiusMd),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.flash_on_rounded, color: VailTheme.primary, size: 40),
              ),
            ],
          ),
          const SizedBox(height: VailTheme.xxl),
          Text(
            'No Conversations Yet',
            style: VailTheme.heading.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VailTheme.sm),
          Text(
            'Your AI-powered insights will appear here once you start chatting.',
            style: VailTheme.bodySmall.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VailTheme.xxl),
          VailButton.primary(
            label: 'Start Your First Chat',
            onTap: onStartChat,
          ),
          const SizedBox(height: 48),
          const _ActionCard(icon: Icons.psychology_rounded, label: 'ANALYZE DATA'),
          const SizedBox(height: VailTheme.md),
          const _ActionCard(icon: Icons.auto_awesome_rounded, label: 'GET IDEAS'),
          const SizedBox(height: VailTheme.md),
          const _ActionCard(icon: Icons.description_rounded, label: 'DRAFT REPORTS'),
        ],
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _GlassBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(VailTheme.radiusFull),
        border: Border.all(color: VailTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: VailTheme.primary, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: VailTheme.micro.copyWith(color: VailTheme.onSurface, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;

  const _FeatureCard({required this.title, required this.desc, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(VailTheme.lg),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(VailTheme.radiusLg),
        border: Border.all(color: VailTheme.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VailTheme.primary, size: 20),
          const SizedBox(height: VailTheme.md),
          Text(title, style: VailTheme.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: VailTheme.xs),
          Text(
            desc,
            style: VailTheme.bodySmall.copyWith(fontSize: 12, color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VailTheme.lg),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(VailTheme.radiusLg),
        border: Border.all(color: VailTheme.ghostBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: VailTheme.primary, size: 20),
          const SizedBox(width: VailTheme.md),
          Text(
            label,
            style: VailTheme.label.copyWith(letterSpacing: 1.0, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
