import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Syntax-highlighted, horizontally scrollable code block with a header
/// showing the language name and a copy-to-clipboard button.
///
/// Used as a replacement for flutter_markdown's default code block rendering.
/// Drop-in via [_CodeElementBuilder] in message_bubble.dart.
class CodeBlock extends StatefulWidget {
  final String code;

  /// highlight.js language identifier e.g. 'dart', 'python', 'bash'.
  /// Pass null for unspecified / plain text.
  final String? language;

  const CodeBlock({
    required this.code,
    this.language,
    super.key,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  // VailTheme.codeTheme is the single source of truth for syntax colours.
  // The 'root' entry sets backgroundColor: VailTheme.background so
  // HighlightView never falls back to its default white background.

  /// Common shorthand aliases → highlight.js IDs.
  static const _aliases = {
    'js': 'javascript',
    'ts': 'typescript',
    'py': 'python',
    'rb': 'ruby',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'yml': 'yaml',
    'md': 'markdown',
    'c++': 'cpp',
    'text': 'plaintext',
  };

  String get _resolvedLanguage {
    final raw = widget.language?.toLowerCase().trim() ?? '';
    if (raw.isEmpty) return 'plaintext';
    return _aliases[raw] ?? raw;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VailTheme.background,
        border: Border.all(color: VailTheme.border),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CodeHeader(
            language: _resolvedLanguage,
            copied: _copied,
            onCopy: _copy,
          ),
          _CodeBody(
            code: widget.code,
            language: _resolvedLanguage,
            theme: VailTheme.codeTheme,
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CodeHeader extends StatelessWidget {
  final String language;
  final bool copied;
  final VoidCallback onCopy;

  const _CodeHeader({
    required this.language,
    required this.copied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: VailTheme.md,
        right: VailTheme.sm,
        top: VailTheme.xs + 2,
        bottom: VailTheme.xs + 2,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VailTheme.radiusSm - 1),
          topRight: Radius.circular(VailTheme.radiusSm - 1),
        ),
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            language == 'plaintext' ? 'CODE' : language.toUpperCase(),
            style: VailTheme.mono.copyWith(
              fontSize: 9,
              letterSpacing: 1.5,
              color: VailTheme.textSecondary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onCopy,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(VailTheme.sm),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  copied ? Icons.check_rounded : Icons.copy_outlined,
                  key: ValueKey(copied),
                  size: 13,
                  color: copied ? VailTheme.accent : VailTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CodeBody extends StatelessWidget {
  final String code;
  final String language;
  final Map<String, TextStyle> theme;

  const _CodeBody({
    required this.code,
    required this.language,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight anchors the code block's vertical size independently
    // of any ancestor SelectableRegion. Without this, the horizontal
    // SingleChildScrollView can report zero height when embedded inside
    // flutter_markdown's SelectableRegion, clipping all content below.
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(VailTheme.md),
        child: HighlightView(
          code,
          language: language == 'plaintext' ? '' : language,
          theme: theme,
          textStyle: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
