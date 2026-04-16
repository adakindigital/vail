import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_glass.dart';

class DocsEmptyState extends StatelessWidget {
  final VoidCallback onNewDocument;

  const DocsEmptyState({required this.onNewDocument, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: VailTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.edit_note_rounded, color: VailTheme.primary, size: 40),
            ),
            const SizedBox(height: 32),
            Text(
              'Your next masterpiece begins here.',
              style: VailTheme.display.copyWith(fontSize: 32),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Harness Vail AI to transform seeds of ideas into structured documents.',
              style: VailTheme.body.copyWith(color: VailTheme.onSurfaceVariant.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Two Action Cards — horizontal scroll so they never overflow on narrow screens
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _DocActionCard(
                    icon: Icons.smart_toy_rounded,
                    title: 'Ask Vail to draft',
                    subtitle: '"Draft a comprehensive technical report on soil PH monitoring..."',
                    onTap: onNewDocument,
                  ),
                  const SizedBox(width: 16),
                  _DocActionCard(
                    icon: Icons.description_rounded,
                    title: 'Paste your notes',
                    subtitle: 'Vail will synthesize and structure your raw thoughts instantly.',
                    onTap: onNewDocument,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 64),
            
            // Templates Section
            Text(
              'QUICK START TEMPLATES',
              style: VailTheme.micro.copyWith(letterSpacing: 2, color: VailTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const Wrap(
              spacing: 16,
              children: [
                _TemplateChip(label: 'Technical Spec', icon: Icons.settings_input_component_rounded),
                _TemplateChip(label: 'Creative Brief', icon: Icons.palette_rounded),
                _TemplateChip(label: 'Research Paper', icon: Icons.science_rounded),
                _TemplateChip(label: '...', icon: Icons.more_horiz_rounded),
              ],
            ),
            
            const SizedBox(height: 80),
            // Bottom Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: VailTheme.surfaceContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                border: Border.all(color: VailTheme.ghostBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: VailTheme.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vail is ready to assist in your writing journey',
                    style: VailTheme.bodySmall.copyWith(fontSize: 11, color: VailTheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 180,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: VailTheme.surfaceContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(VailTheme.radiusLg),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VailTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: VailTheme.primary, size: 20),
            ),
            const Spacer(),
            Text(title, style: VailTheme.heading.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: VailTheme.bodySmall.copyWith(color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _TemplateChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        border: Border.all(color: VailTheme.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: VailTheme.primary, size: 16),
          const SizedBox(width: 10),
          Text(label, style: VailTheme.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
