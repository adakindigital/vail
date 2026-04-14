import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';

/// Full-screen terminal-style document viewer / live writer.
///
/// Two modes:
///   • Streaming — [document] is null, watches [DocumentsViewModel.streamingContent].
///   • Final      — [document] is set, renders the completed content.
class DocumentEditorView extends StatefulWidget {
  final VailDocument? document;

  const DocumentEditorView({this.document, super.key});

  @override
  State<DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends State<DocumentEditorView> {
  bool _copied = false;

  String _content(DocumentsViewModel vm) =>
      widget.document?.content ?? vm.streamingContent;

  bool _isGenerating(DocumentsViewModel vm) =>
      widget.document == null && vm.isGenerating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Consumer<DocumentsViewModel>(
        builder: (context, vm, _) {
          final content = _content(vm);
          final isGenerating = _isGenerating(vm);
          final doc = widget.document;

          return Column(
            children: [
              _TerminalTopBar(
                onBack: () => Navigator.of(context).pop(),
              ),
              _MetadataBar(
                docId: doc?.terminalId ?? 'VT-DRAFT',
                timestamp: doc?.terminalTimestamp ??
                    _nowTimestamp(),
                status: isGenerating ? 'DRAFT_COMMIT' : 'FINAL_COMMIT',
              ),
              if (vm.generationError != null && widget.document == null)
                _ErrorBanner(message: vm.generationError!),
              Expanded(
                child: content.isEmpty && isGenerating
                    ? const _GeneratingPlaceholder()
                    : _DocumentBody(content: content),
              ),
              _ActionFooter(
                wordCount: doc?.wordCountLabel ??
                    _streamingWordCount(content),
                readingTime: doc?.readingTimeLabel ??
                    _streamingReadingTime(content),
                isGenerating: isGenerating,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  setState(() => _copied = true);
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted) setState(() => _copied = false);
                },
                copied: _copied,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _nowTimestamp() {
    final d = DateTime.now();
    final date =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    return '${date}_$time';
  }

  static String _streamingWordCount(String content) {
    if (content.isEmpty) return '0 words';
    final n = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '$n words';
  }

  static String _streamingReadingTime(String content) {
    if (content.isEmpty) return '0m read';
    final n = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '${(n / 200).ceil()}m read';
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TerminalTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TerminalTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + VailTheme.sm,
        left: VailTheme.sm,
        right: VailTheme.md,
        bottom: VailTheme.sm,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(VailTheme.sm),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: VailTheme.textSecondary),
            ),
          ),
          const SizedBox(width: VailTheme.xs),
          const Text('VAIL', style: VailTheme.brandLabel),
          const SizedBox(width: VailTheme.xs),
          Text(
            '// DOC_WRITER',
            style: VailTheme.mono.copyWith(color: VailTheme.textSecondary),
          ),
          const Spacer(),
          _OutlinedChip(label: 'NEW CHAT', onTap: onBack),
        ],
      ),
    );
  }
}

// ── Metadata bar ──────────────────────────────────────────────────────────────

class _MetadataBar extends StatelessWidget {
  final String docId;
  final String timestamp;
  final String status;

  const _MetadataBar({
    required this.docId,
    required this.timestamp,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.sm,
      ),
      color: VailTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MetaChip(label: 'DOC_ID', value: docId),
            const SizedBox(width: VailTheme.md),
            _MetaChip(label: 'TIMESTAMP', value: timestamp),
            const SizedBox(width: VailTheme.md),
            const _MetaChip(label: 'ENCRYPTION', value: 'AES-256_ACTIVE',
                valueColor: VailTheme.accent),
            const SizedBox(width: VailTheme.md),
            _MetaChip(label: 'STATUS', value: status,
                valueColor: status == 'FINAL_COMMIT'
                    ? VailTheme.accent
                    : VailTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: VailTheme.mono.copyWith(
            fontSize: 8,
            color: VailTheme.textMuted,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: VailTheme.mono.copyWith(
            fontSize: 8,
            color: valueColor ?? VailTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── Document body ─────────────────────────────────────────────────────────────

class _DocumentBody extends StatelessWidget {
  final String content;

  const _DocumentBody({required this.content});

  /// Pre-process markdown: extract H1 as title block, number H2 sections.
  static _ProcessedDoc _process(String raw) {
    final lines = raw.split('\n');
    String title = '';
    int sectionCount = 0;
    final bodyLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('# ') && title.isEmpty) {
        title = line.substring(2).trim();
      } else if (line.startsWith('## ')) {
        sectionCount++;
        final num = sectionCount.toString().padLeft(2, '0');
        bodyLines.add('## $num.  ${line.substring(3).trim()}');
      } else {
        bodyLines.add(line);
      }
    }

    return _ProcessedDoc(
      title: title,
      body: bodyLines.join('\n').trim(),
    );
  }

  static final MarkdownStyleSheet _styles = MarkdownStyleSheet(
    p: VailTheme.body.copyWith(fontSize: 14, height: 1.8, color: const Color(0xFFCCCCCC)),
    strong: VailTheme.body.copyWith(fontSize: 14, height: 1.8, fontWeight: FontWeight.w700),
    em: VailTheme.body.copyWith(fontSize: 14, fontStyle: FontStyle.italic),
    // H2 becomes the numbered section header
    h2: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: VailTheme.accent,
      letterSpacing: 2,
      height: 2.5,
    ),
    h3: VailTheme.body.copyWith(
        fontSize: 13, fontWeight: FontWeight.w600, color: VailTheme.textPrimary),
    h4: VailTheme.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    code: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 12,
      color: VailTheme.accent,
      backgroundColor: VailTheme.accentSubtle,
    ),
    codeblockDecoration: BoxDecoration(
      color: VailTheme.surface,
      border: Border.all(color: VailTheme.border),
      borderRadius: BorderRadius.circular(VailTheme.radiusSm),
    ),
    codeblockPadding: const EdgeInsets.all(VailTheme.md),
    blockquotePadding: const EdgeInsets.only(left: VailTheme.md),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: VailTheme.accent.withValues(alpha: 0.5), width: 2),
      ),
    ),
    listBullet: VailTheme.body.copyWith(fontSize: 14, color: VailTheme.accent),
    listIndent: 24,
    tableHead: VailTheme.body.copyWith(fontWeight: FontWeight.w700),
    tableBody: VailTheme.body.copyWith(fontSize: 13),
    tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md, vertical: VailTheme.sm),
    tableBorder: TableBorder.all(color: VailTheme.border, width: 1),
    a: VailTheme.body.copyWith(
      fontSize: 14,
      color: VailTheme.accent,
      decoration: TextDecoration.underline,
    ),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: VailTheme.border)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final processed = _process(content);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg, vertical: VailTheme.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (processed.title.isNotEmpty) ...[
                // Large terminal-style title
                Text(
                  processed.title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: VailTheme.textPrimary,
                    letterSpacing: 2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: VailTheme.xs),
                // Separator line with accent
                Container(
                  height: 1,
                  color: VailTheme.accent.withValues(alpha: 0.3),
                  margin: const EdgeInsets.only(bottom: VailTheme.xl),
                ),
              ],
              if (processed.body.isNotEmpty)
                MarkdownBody(
                  data: processed.body,
                  styleSheet: _styles,
                  selectable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessedDoc {
  final String title;
  final String body;

  const _ProcessedDoc({required this.title, required this.body});
}

// ── Action footer ─────────────────────────────────────────────────────────────

class _ActionFooter extends StatelessWidget {
  final String wordCount;
  final String readingTime;
  final bool isGenerating;
  final VoidCallback onCopy;
  final bool copied;

  const _ActionFooter({
    required this.wordCount,
    required this.readingTime,
    required this.isGenerating,
    required this.onCopy,
    required this.copied,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg, vertical: VailTheme.sm),
      decoration: const BoxDecoration(
        color: VailTheme.surface,
        border: Border(top: BorderSide(color: VailTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Stats
            Text(
              'WORD_COUNT: ${wordCount.toUpperCase().replaceAll(' ', '_')}',
              style: VailTheme.mono.copyWith(fontSize: 8, letterSpacing: 1),
            ),
            const SizedBox(width: VailTheme.md),
            Text(
              'READING_TIME: ${readingTime.toUpperCase().replaceAll(' ', '_')}',
              style: VailTheme.mono
                  .copyWith(fontSize: 8, color: VailTheme.textMuted, letterSpacing: 1),
            ),
            const Spacer(),
            if (isGenerating)
              const SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                    strokeWidth: 1.2, color: VailTheme.accent),
              )
            else
              _FooterButton(
                label: copied ? 'COPIED ✓' : 'COPY_TEXT',
                onTap: onCopy,
                filled: false,
                accentLabel: copied,
              ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool accentLabel;

  const _FooterButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.accentLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md, vertical: VailTheme.xs + 2),
        decoration: BoxDecoration(
          color: filled ? VailTheme.accent : Colors.transparent,
          border: Border.all(
              color: accentLabel || filled ? VailTheme.accent : VailTheme.border),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Text(
          label,
          style: VailTheme.mono.copyWith(
            fontSize: 8,
            letterSpacing: 1.5,
            color: filled
                ? VailTheme.onAccent
                : accentLabel
                    ? VailTheme.accent
                    : VailTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _OutlinedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md, vertical: VailTheme.xs + 1),
        decoration: BoxDecoration(
          border: Border.all(color: VailTheme.accent),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Text(
          label,
          style: VailTheme.mono.copyWith(color: VailTheme.accent, fontSize: 9),
        ),
      ),
    );
  }
}

class _GeneratingPlaceholder extends StatelessWidget {
  const _GeneratingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: VailTheme.accent),
          ),
          const SizedBox(height: VailTheme.md),
          Text(
            'WRITING_DOCUMENT...',
            style: VailTheme.mono.copyWith(
                color: VailTheme.textSecondary, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg, vertical: VailTheme.sm),
      color: VailTheme.error.withValues(alpha: 0.1),
      child: Text(message,
          style: VailTheme.bodySmall.copyWith(color: VailTheme.error)),
    );
  }
}
