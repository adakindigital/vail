import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';
import 'package:vail_app/views/chat/widgets/code_block.dart';

/// Terminal-style message block.
///
/// Both user and assistant messages render as full-width bordered blocks
/// with a header row showing the sender label and status — matching the
/// PRECISION_TERMINAL design language.
class MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  /// Zero-based position in the messages list. Used to generate INPUT_XXXX IDs.
  final int index;

  const MessageBubble({
    required this.message,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.xs + 1,
      ),
      decoration: BoxDecoration(
        color: message.isFromUser ? VailTheme.userBubble : VailTheme.surface,
        border: Border.all(
          color: message.isFromUser
              ? VailTheme.accent.withValues(alpha: 0.15)
              : VailTheme.border,
        ),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MessageHeader(message: message, index: index),
          const Divider(height: 1, thickness: 1, color: VailTheme.border),
          _MessageContent(message: message),
        ],
      ),
    );
  }
}

// ── Header row ────────────────────────────────────────────────────────────────

class _MessageHeader extends StatelessWidget {
  final ConversationMessage message;
  final int index;

  const _MessageHeader({required this.message, required this.index});

  String get _inputId => 'INPUT_${(index + 1).toString().padLeft(4, '0')}';

  String get _assistantStatus {
    if (message.isStreaming && message.content.isEmpty) return 'PROCESSING';
    if (message.isStreaming) return 'STREAMING';
    return 'COMPLETE';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isFromUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.md,
          vertical: VailTheme.sm - 1,
        ),
        child: Row(
          children: [
            Text(
              'USER',
              style: VailTheme.mono.copyWith(
                fontSize: 8,
                color: VailTheme.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              ' // $_inputId',
              style: VailTheme.mono.copyWith(
                fontSize: 8,
                color: VailTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    // Assistant
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md,
        vertical: VailTheme.sm - 1,
      ),
      child: Row(
        children: [
          Text(
            'VAIL_ASSISTANT',
            style: VailTheme.mono.copyWith(
              fontSize: 8,
              color: VailTheme.accent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: VailTheme.sm),
          _StatusBadge(status: _assistantStatus),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'COMPLETE':
        return VailTheme.accent;
      case 'STREAMING':
        return const Color(0xFFE5C07B);
      case 'PROCESSING':
        return VailTheme.textSecondary;
      default:
        return VailTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.sm, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: _color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'STREAMING' || status == 'PROCESSING')
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: SizedBox(
                width: 5,
                height: 5,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: _color,
                ),
              ),
            ),
          Text(
            status,
            style: VailTheme.mono.copyWith(
              fontSize: 7,
              color: _color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message content ───────────────────────────────────────────────────────────

class _MessageContent extends StatelessWidget {
  final ConversationMessage message;

  const _MessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isFromUser) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          VailTheme.md, VailTheme.sm, VailTheme.md, VailTheme.md,
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
              style: VailTheme.body.copyWith(color: VailTheme.onUserBubble),
            ),
          ],
        ),
      );
    }

    // Assistant — typing indicator or markdown
    if (message.isStreaming && message.content.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          VailTheme.md, VailTheme.sm, VailTheme.md, VailTheme.md,
        ),
        child: _TypingIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VailTheme.md, VailTheme.sm, VailTheme.md, VailTheme.md,
      ),
      child: Column(
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
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: VailTheme.accent),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmExternalLink(BuildContext context, Uri uri) async {
    final display = uri.toString().length > 60
        ? '${uri.toString().substring(0, 57)}...'
        : uri.toString();

    final confirmed = await showVailDialog<bool>(
      context: context,
      title: 'EXTERNAL LINK',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are about to leave Vail and open an external website.',
            style: VailTheme.body.copyWith(color: VailTheme.textSecondary),
          ),
          const SizedBox(height: VailTheme.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VailTheme.md),
            decoration: BoxDecoration(
              color: VailTheme.background,
              border: Border.all(color: VailTheme.border),
              borderRadius: BorderRadius.circular(VailTheme.radiusSm),
            ),
            child: Text(
              display,
              style: VailTheme.mono.copyWith(
                color: VailTheme.accent,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
      actions: const [
        VailDialogAction(label: 'CANCEL', value: false),
        VailDialogAction(label: 'PROCEED', value: true, isPrimary: true),
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
      h2: VailTheme.heading.copyWith(fontSize: 20),
      h3: VailTheme.body.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      h4: VailTheme.body.copyWith(fontWeight: FontWeight.w600),
      h5: VailTheme.body.copyWith(fontWeight: FontWeight.w600, color: VailTheme.textSecondary),
      h6: VailTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
      code: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 12,
        color: VailTheme.accent,
        backgroundColor: VailTheme.accentSubtle,
      ),
      codeblockDecoration: BoxDecoration(
        color: VailTheme.background,
        border: Border.all(color: VailTheme.border),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      codeblockPadding: const EdgeInsets.all(VailTheme.md),
      blockquotePadding: const EdgeInsets.only(left: VailTheme.md, top: VailTheme.xs, bottom: VailTheme.xs),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: VailTheme.accent.withValues(alpha: 0.5), width: 2),
        ),
      ),
      listBullet: VailTheme.body.copyWith(color: VailTheme.accent),
      listIndent: 20,
      tableHead: VailTheme.body.copyWith(fontWeight: FontWeight.w700),
      tableBody: VailTheme.bodySmall,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: VailTheme.md, vertical: VailTheme.sm),
      tableBorder: TableBorder.all(color: VailTheme.border, width: 1,
          borderRadius: BorderRadius.circular(VailTheme.radiusSm)),
      tableColumnWidth: const FlexColumnWidth(),
      a: VailTheme.body.copyWith(
        color: VailTheme.accent,
        decoration: TextDecoration.underline,
        decorationColor: VailTheme.accent.withValues(alpha: 0.5),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.border)),
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
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 200),
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
          SizedBox(width: 4),
          _Dot(delay: Duration(milliseconds: 160)),
          SizedBox(width: 4),
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
        duration: const Duration(milliseconds: 600), vsync: this);
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
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: VailTheme.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
