import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';
import 'package:vail_app/views/chat/widgets/code_block.dart';

/// Forest Sanctuary message bubble.
///
/// User messages: right-aligned, dark surface, no header label.
/// Assistant messages: left-aligned, AI avatar + "Vail Core" label,
/// emerald glow border, bento action grid for long responses.
class MessageBubble extends StatelessWidget {
  final ConversationMessage message;
  final int index;

  const MessageBubble({
    required this.message,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.xs + 2,
      ),
      child: message.isFromUser
          ? _UserBubble(message: message)
          : _AssistantBubble(message: message),
    );
  }
}

// ── User bubble ───────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final ConversationMessage message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: VailTheme.lg + 4,
              vertical: VailTheme.md + 2,
            ),
            decoration: BoxDecoration(
              color: VailTheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(VailTheme.radiusLg),
                topRight: Radius.circular(VailTheme.radiusLg),
                bottomLeft: Radius.circular(VailTheme.radiusLg),
                bottomRight: Radius.circular(VailTheme.radiusSm),
              ),
              border: Border.all(color: VailTheme.ghostBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageBytes != null) ...[
                  _AttachedImage(bytes: message.imageBytes!),
                  const SizedBox(height: VailTheme.sm),
                ],
                SelectableText(
                  message.content,
                  style: VailTheme.body.copyWith(color: VailTheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Assistant bubble ──────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final ConversationMessage message;

  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: VailTheme.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(
              color: VailTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: VailTheme.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: VailTheme.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Vail Core" label
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: VailTheme.xs),
                child: Text(
                  'Vail Core',
                  style: VailTheme.caption.copyWith(
                    color: VailTheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Bubble
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                decoration: BoxDecoration(
                  color: VailTheme.surfaceContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(VailTheme.radiusSm),
                    topRight: Radius.circular(VailTheme.radiusLg),
                    bottomLeft: Radius.circular(VailTheme.radiusLg),
                    bottomRight: Radius.circular(VailTheme.radiusLg),
                  ),
                  border: Border.all(
                    color: VailTheme.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: VailTheme.aiCardGlow,
                ),
                padding: const EdgeInsets.all(VailTheme.lg),
                child: _AssistantContent(message: message),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Assistant message content ─────────────────────────────────────────────────

class _AssistantContent extends StatelessWidget {
  final ConversationMessage message;

  const _AssistantContent({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming && message.content.isEmpty) {
      return const _TypingIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: message.content,
          selectable: !message.isStreaming,
          styleSheet: _markdownStyles(),
          builders: {'code': _CodeElementBuilder()},
          onTapLink: (text, href, title) {
            if (href == null) return;
            final uri = Uri.tryParse(href);
            if (uri != null) _confirmExternalLink(context, uri);
          },
        ),
        if (message.isStreaming) ...[
          const SizedBox(height: VailTheme.sm),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: VailTheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmExternalLink(BuildContext context, Uri uri) async {
    final display = uri.toString().length > 60
        ? '${uri.toString().substring(0, 57)}...'
        : uri.toString();

    final confirmed = await showVailDialog<bool>(
      context: context,
      title: 'External Link',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are about to leave Vail and open an external website.',
            style: VailTheme.body.copyWith(color: VailTheme.onSurfaceVariant),
          ),
          const SizedBox(height: VailTheme.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VailTheme.md),
            decoration: BoxDecoration(
              color: VailTheme.surfaceContainerLow,
              border: Border.all(color: VailTheme.ghostBorder),
              borderRadius: BorderRadius.circular(VailTheme.radiusSm),
            ),
            child: Text(
              display,
              style: VailTheme.bodySmall.copyWith(color: VailTheme.primary),
            ),
          ),
        ],
      ),
      actions: const [
        VailDialogAction(label: 'Cancel', value: false),
        VailDialogAction(label: 'Open link', value: true, isPrimary: true),
      ],
    );

    if (confirmed == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _markdownStyles() {
    return MarkdownStyleSheet(
      p: VailTheme.body,
      strong: VailTheme.body.copyWith(fontWeight: FontWeight.w700),
      em: VailTheme.body.copyWith(fontStyle: FontStyle.italic),
      h1: VailTheme.heading,
      h2: VailTheme.heading.copyWith(fontSize: 18),
      h3: VailTheme.subheading.copyWith(fontSize: 16),
      h4: VailTheme.label.copyWith(fontWeight: FontWeight.w700),
      h5: VailTheme.label.copyWith(color: VailTheme.onSurfaceVariant),
      h6: VailTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
      code: VailTheme.inlineCode,
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF031109),
        border: Border.all(color: VailTheme.ghostBorder),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      codeblockPadding: const EdgeInsets.all(VailTheme.md),
      blockquotePadding: const EdgeInsets.only(
        left: VailTheme.md,
        top: VailTheme.xs,
        bottom: VailTheme.xs,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: VailTheme.primary.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
        color: VailTheme.primaryContainer,
      ),
      listBullet: VailTheme.body.copyWith(color: VailTheme.primary),
      listIndent: 20,
      tableHead: VailTheme.label.copyWith(fontWeight: FontWeight.w700),
      tableBody: VailTheme.bodySmall,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md,
        vertical: VailTheme.sm,
      ),
      tableBorder: TableBorder.all(
        color: VailTheme.ghostBorder,
        width: 1,
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      tableColumnWidth: const FlexColumnWidth(),
      a: VailTheme.body.copyWith(
        color: VailTheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: VailTheme.primary.withValues(alpha: 0.4),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
    );
  }
}

// ── Bento action cards ─────────────────────────────────────────────────────────
// Rendered below long assistant responses as contextual quick-action chips.

class BentoActionGrid extends StatelessWidget {
  const BentoActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: VailTheme.md),
      child: Wrap(
        spacing: VailTheme.sm,
        runSpacing: VailTheme.sm,
        children: [
          _BentoChip(
            icon: Icons.edit_note_rounded,
            label: 'Refine this',
            onTap: () {},
          ),
          _BentoChip(
            icon: Icons.summarize_rounded,
            label: 'Summarise',
            onTap: () {},
          ),
          _BentoChip(
            icon: Icons.content_copy_rounded,
            label: 'Copy',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _BentoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BentoChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.md,
          vertical: VailTheme.xs + 2,
        ),
        decoration: BoxDecoration(
          color: VailTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: VailTheme.primary),
            const SizedBox(width: VailTheme.xs + 2),
            Text(
              label,
              style: VailTheme.caption.copyWith(
                color: VailTheme.onSurface,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Code block element builder ────────────────────────────────────────────────

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final rawClass = element.attributes['class'] ?? '';
    final lang = rawClass.replaceAll('language-', '').trim();

    final isBlock = lang.isNotEmpty || code.contains('\n');
    if (!isBlock) return null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VailTheme.xs),
      child: CodeBlock(
        code: code.trimRight(),
        language: lang.isEmpty ? null : lang,
      ),
    );
  }
}

// ── Attached image ────────────────────────────────────────────────────────────

class _AttachedImage extends StatelessWidget {
  final Uint8List bytes;

  const _AttachedImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 220),
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: Duration.zero),
          SizedBox(width: 5),
          _Dot(delay: Duration(milliseconds: 160)),
          SizedBox(width: 5),
          _Dot(delay: Duration(milliseconds: 320)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;

  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: VailTheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
