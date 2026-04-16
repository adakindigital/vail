import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Syntax-highlighted code block with Mac-style window controls
/// and a high-fidelity language header.
class CodeBlock extends StatefulWidget {
  final String code;
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF031109), // surfaceContainerLowest
        border: Border.all(color: VailTheme.ghostBorder),
        borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md,
        vertical: VailTheme.sm + 2,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF031109),
        border: Border(bottom: BorderSide(color: VailTheme.ghostBorder)),
      ),
      child: Row(
        children: [
          // Mac-style dots
          const Row(
            children: [
              _Dot(color: Color(0xFFFF5F56)),
              SizedBox(width: 6),
              _Dot(color: Color(0xFFFFBD2E)),
              SizedBox(width: 6),
              _Dot(color: Color(0xFF27C93F)),
            ],
          ),
          const Spacer(),
          Text(
            language.toUpperCase(),
            style: VailTheme.micro.copyWith(
              color: VailTheme.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: VailTheme.md),
          GestureDetector(
            onTap: onCopy,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              copied ? Icons.check_rounded : Icons.copy_outlined,
              size: 14,
              color: copied
                  ? VailTheme.primary
                  : VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

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
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(VailTheme.lg),
        child: HighlightView(
          code,
          language: language == 'plaintext' ? '' : language,
          theme: theme,
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
