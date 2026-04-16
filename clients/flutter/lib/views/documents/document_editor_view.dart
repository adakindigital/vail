import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_error_banner.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';
import 'package:vail_app/views/documents/doc_pdf_exporter.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';

class DocumentEditorView extends StatefulWidget {
  final VailDocument? document;
  const DocumentEditorView({this.document, super.key});
  @override
  State<DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends State<DocumentEditorView> {
  bool _copied = false;
  bool _exporting = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _export(VailDocument doc) async {
    setState(() => _exporting = true);
    try {
      await exportDocumentAsPdf(doc);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Consumer<DocumentsViewModel>(
        builder: (context, vm, _) {
          final content = widget.document?.content ?? vm.streamingContent;
          final isGenerating = widget.document == null && vm.isGenerating;
          final doc = widget.document;

          // Build a temporary VailDocument for export when streaming is done
          final exportDoc = doc ?? (content.isNotEmpty && !isGenerating
              ? VailDocument(
                  title: _extractTitle(content) ?? 'Vail Document',
                  content: content,
                  prompt: '',
                  createdAt: DateTime.now(),
                )
              : null);

          return Column(
            children: [
              _DocHeader(
                content: content,
                document: doc,
                isGenerating: isGenerating,
                onBack: () => Navigator.pop(context),
              ),
              if (vm.generationError != null && doc == null)
                VailErrorBanner(message: vm.generationError!),
              Expanded(
                child: content.isEmpty && isGenerating
                    ? const _ComposingState()
                    : _DocBody(content: content, isGenerating: isGenerating),
              ),
              _DocToolbar(
                content: content,
                document: doc,
                isGenerating: isGenerating,
                copied: _copied,
                exporting: _exporting,
                onCopy: () => _copy(content),
                onExport: exportDoc != null ? () => _export(exportDoc) : null,
              ),
            ],
          );
        },
      ),
    );
  }

  static String? _extractTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
    }
    return null;
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  final String content;
  final VailDocument? document;
  final bool isGenerating;
  final VoidCallback onBack;

  const _DocHeader({
    required this.content,
    required this.document,
    required this.isGenerating,
    required this.onBack,
  });

  String _extractTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final title = document?.title ?? _extractTitle(content);
    final terminalId = document?.terminalId;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPad + VailTheme.sm,
        left: VailTheme.sm,
        right: VailTheme.lg,
        bottom: VailTheme.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.ghostBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            color: VailTheme.onSurfaceVariant,
            onPressed: onBack,
          ),
          // Doc icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: VailTheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              border: Border.all(color: VailTheme.primary.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.article_outlined, color: VailTheme.primary, size: 16),
          ),
          const SizedBox(width: VailTheme.sm + 2),
          // Title + metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title.isNotEmpty
                    ? Text(
                        title,
                        style: VailTheme.label.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VailTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        isGenerating ? 'Composing…' : 'Document',
                        style: VailTheme.label.copyWith(
                          fontSize: 14,
                          color: VailTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                if (terminalId != null)
                  Text(
                    terminalId,
                    style: VailTheme.micro.copyWith(
                      color: VailTheme.primary.withValues(alpha: 0.6),
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
          ),
          // Status badge
          if (isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: 4),
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 8, height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: VailTheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'WRITING',
                    style: VailTheme.micro.copyWith(color: VailTheme.primary, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Composing (empty) state ────────────────────────────────────────────────────

class _ComposingState extends StatefulWidget {
  const _ComposingState();
  @override
  State<_ComposingState> createState() => _ComposingStateState();
}

class _ComposingStateState extends State<_ComposingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VailTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: VailTheme.primaryContainer.withValues(
                    alpha: 0.1 + _ctrl.value * 0.12,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: VailTheme.primary.withValues(alpha: 0.2 + _ctrl.value * 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VailTheme.primary.withValues(alpha: 0.1 + _ctrl.value * 0.15),
                      blurRadius: 24 + _ctrl.value * 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_note_rounded, color: VailTheme.primary, size: 32),
              ),
            ),
            const SizedBox(height: VailTheme.xl),
            Text(
              'Vail is composing',
              style: VailTheme.subheading.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: VailTheme.sm),
            Text(
              'Your document will appear as it streams in.',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xl),
            // Animated skeleton lines
            _SkeletonLines(animation: _ctrl),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLines extends StatelessWidget {
  final Animation<double> animation;
  const _SkeletonLines({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Column(
        children: [
          for (final frac in [1.0, 0.85, 0.92, 0.7])
            Container(
              height: 10,
              width: 240 * frac,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: VailTheme.surfaceContainerHigh.withValues(
                  alpha: 0.4 + animation.value * 0.3,
                ),
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Document body ─────────────────────────────────────────────────────────────

class _DocBody extends StatelessWidget {
  final String content;
  final bool isGenerating;

  const _DocBody({required this.content, required this.isGenerating});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Constrain readable line length — document feel
    final maxWidth = width > 800 ? 720.0 : double.infinity;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              VailTheme.xl + 4,
              VailTheme.xl,
              VailTheme.xl + 4,
              VailTheme.xxl,
            ),
            decoration: BoxDecoration(
              color: VailTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(VailTheme.radiusMd),
              border: Border.all(color: VailTheme.ghostBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: content,
                  selectable: !isGenerating,
                  styleSheet: _buildStyleSheet(),
                  builders: {'code': _DocCodeBuilder()},
                ),
                if (isGenerating) ...[
                  const SizedBox(height: VailTheme.sm),
                  _StreamingCursor(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet() {
    return MarkdownStyleSheet(
      // Headings
      h1: VailTheme.display.copyWith(
        fontSize: 28,
        color: VailTheme.onSurface,
        height: 1.3,
      ),
      h2: VailTheme.heading.copyWith(
        fontSize: 20,
        color: VailTheme.primary,
        height: 1.4,
      ),
      h3: VailTheme.subheading.copyWith(
        fontSize: 16,
        color: VailTheme.onSurface.withValues(alpha: 0.85),
        height: 1.4,
      ),
      h4: VailTheme.label.copyWith(
        fontSize: 14,
        color: VailTheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      // Body
      p: VailTheme.body.copyWith(height: 1.85, fontSize: 15),
      // Spacing
      h1Padding: const EdgeInsets.only(top: 8, bottom: 16),
      h2Padding: const EdgeInsets.only(top: 24, bottom: 10),
      h3Padding: const EdgeInsets.only(top: 18, bottom: 8),
      pPadding: const EdgeInsets.only(bottom: 12),
      // Lists
      listBullet: VailTheme.body.copyWith(
        color: VailTheme.primary,
        height: 1.85,
      ),
      listIndent: 24,
      // Inline code
      code: VailTheme.inlineCode,
      // Code block
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF031109),
        border: Border.all(color: VailTheme.ghostBorder),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      codeblockPadding: const EdgeInsets.all(VailTheme.lg),
      // Blockquote
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: VailTheme.primary.withValues(alpha: 0.5), width: 3),
        ),
        color: VailTheme.primaryContainer.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(VailTheme.radiusSm),
          bottomRight: Radius.circular(VailTheme.radiusSm),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.sm,
      ),
      blockquote: VailTheme.body.copyWith(
        color: VailTheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontStyle: FontStyle.italic,
        height: 1.7,
      ),
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: VailTheme.primary.withValues(alpha: 0.15), width: 1),
        ),
      ),
      // Strong / em
      strong: VailTheme.body.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.85,
        color: VailTheme.onSurface,
      ),
      em: VailTheme.body.copyWith(
        fontStyle: FontStyle.italic,
        height: 1.85,
        color: VailTheme.onSurfaceVariant,
      ),
    );
  }
}

// Blinking cursor shown at the end of streaming content
class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(
      width: 2, height: 18,
      decoration: BoxDecoration(
        color: VailTheme.primary,
        borderRadius: BorderRadius.circular(1),
        boxShadow: VailTheme.primaryGlow,
      ),
    ),
  );
}

// ── Code block builder ────────────────────────────────────────────────────────

class _DocCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final rawClass = element.attributes['class'] ?? '';
    final lang = rawClass.replaceAll('language-', '').trim();
    // Single-line inline code is handled by the stylesheet
    if (lang.isEmpty && !code.contains('\n')) return null;
    return _CodeBlock(code: code.trimRight(), language: lang.isEmpty ? null : lang);
  }
}

class _CodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  const _CodeBlock({required this.code, this.language});
  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VailTheme.sm),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF031109),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code block header bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VailTheme.md,
                vertical: VailTheme.xs + 2,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: VailTheme.ghostBorder)),
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: Row(
                children: [
                  if (widget.language != null)
                    Text(
                      widget.language!.toUpperCase(),
                      style: VailTheme.micro.copyWith(
                        color: VailTheme.primary.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                        fontSize: 9,
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _copy,
                    child: Text(
                      _copied ? 'COPIED' : 'COPY',
                      style: VailTheme.micro.copyWith(
                        color: _copied ? VailTheme.primary : VailTheme.textMuted,
                        letterSpacing: 1.2,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(VailTheme.md),
              child: SelectableText(
                widget.code,
                style: VailTheme.inlineCode.copyWith(
                  backgroundColor: Colors.transparent,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _DocToolbar extends StatelessWidget {
  final String content;
  final VailDocument? document;
  final bool isGenerating;
  final bool copied;
  final bool exporting;
  final VoidCallback onCopy;
  final VoidCallback? onExport;

  const _DocToolbar({
    required this.content,
    required this.document,
    required this.isGenerating,
    required this.copied,
    required this.exporting,
    required this.onCopy,
    required this.onExport,
  });

  int _wordCount(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String _readingTime(int words) {
    final min = (words / 200).ceil();
    return '${min}m read';
  }

  @override
  Widget build(BuildContext context) {
    final words = document?.wordCount ?? _wordCount(content);
    final terminalId = document?.terminalId;

    return Container(
      padding: EdgeInsets.only(
        left: VailTheme.lg,
        right: VailTheme.lg,
        top: VailTheme.sm + 2,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : VailTheme.md,
      ),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainerLow,
        border: const Border(top: BorderSide(color: VailTheme.ghostBorder)),
      ),
      child: Row(
        children: [
          // Word count chip
          _ToolbarChip(
            icon: Icons.notes_rounded,
            label: '$words words',
          ),
          const SizedBox(width: VailTheme.sm),
          if (words > 0) ...[
            _ToolbarChip(
              icon: Icons.schedule_rounded,
              label: _readingTime(words),
            ),
            const SizedBox(width: VailTheme.sm),
          ],
          if (terminalId != null) ...[
            Text(
              terminalId,
              style: VailTheme.micro.copyWith(
                color: VailTheme.primary.withValues(alpha: 0.4),
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const Spacer(),
          // Actions
          if (isGenerating)
            Text(
              'Writing…',
              style: VailTheme.micro.copyWith(
                color: VailTheme.primary.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Copy button
                GestureDetector(
                  onTap: content.isNotEmpty ? onCopy : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: VailTheme.md,
                      vertical: VailTheme.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: copied
                          ? VailTheme.primaryContainer.withValues(alpha: 0.2)
                          : VailTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                      border: Border.all(color: VailTheme.ghostBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 11,
                          color: copied ? VailTheme.primary : VailTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          copied ? 'COPIED' : 'COPY',
                          style: VailTheme.micro.copyWith(
                            color: copied ? VailTheme.primary : VailTheme.onSurfaceVariant,
                            letterSpacing: 1.5,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: VailTheme.sm),
                // Export PDF button
                GestureDetector(
                  onTap: (onExport != null && !exporting) ? onExport : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: VailTheme.md,
                      vertical: VailTheme.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: VailTheme.primary,
                      borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                      boxShadow: exporting ? null : VailTheme.primaryGlow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (exporting)
                          const SizedBox(
                            width: 11, height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: VailTheme.onPrimary,
                            ),
                          )
                        else
                          const Icon(Icons.picture_as_pdf_rounded, size: 11, color: VailTheme.onPrimary),
                        const SizedBox(width: 5),
                        Text(
                          exporting ? 'EXPORTING…' : 'EXPORT PDF',
                          style: VailTheme.micro.copyWith(
                            color: VailTheme.onPrimary,
                            letterSpacing: 1.5,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ToolbarChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: VailTheme.textMuted),
      const SizedBox(width: 4),
      Text(
        label,
        style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 10),
      ),
    ],
  );
}
