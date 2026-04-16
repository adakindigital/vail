import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';

/// Exports a [VailDocument] as a nicely formatted branded PDF.
///
/// Uses the `printing` package to invoke the platform share/save sheet so the
/// user can save to Files, AirDrop, print, etc. Works on iOS, Android, web,
/// and macOS.
Future<void> exportDocumentAsPdf(VailDocument doc) async {
  final pdf = pw.Document(
    title: doc.title,
    author: 'Vail AI — Adakin Digital',
  );

  // Built-in PDF fonts — always available, no network required.
  final fontRegular = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final fontItalic = pw.Font.helveticaOblique();
  final fontMono = pw.Font.courier();

  // Brand colours for the PDF (light document — inverted from the app theme).
  const emerald = PdfColor.fromInt(0xFF21C45D);
  const emeraldLight = PdfColor.fromInt(0xFFDCFCE7);
  const ink = PdfColor.fromInt(0xFF0F172A);
  const inkMuted = PdfColor.fromInt(0xFF475569);
  const codeBackground = PdfColor.fromInt(0xFFF1F5F9);
  const ruleLine = PdfColor.fromInt(0xFFE2E8F0);

  final blocks = _parseMarkdown(doc.content);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          top: 0,
          bottom: 48,
          left: 56,
          right: 56,
        ),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      header: (ctx) => _buildPageHeader(doc, fontBold, fontRegular, emerald, ink, inkMuted, ctx),
      footer: (ctx) => _buildPageFooter(doc, fontRegular, inkMuted, ctx),
      build: (ctx) => [
        // Document title block
        pw.SizedBox(height: 24),
        pw.Text(
          doc.title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 26,
            color: ink,
            lineSpacing: 4,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 3,
          width: 48,
          color: emerald,
        ),
        pw.SizedBox(height: 24),
        // Body blocks
        ...blocks.map((b) => _renderBlock(
          b,
          fontRegular: fontRegular,
          fontBold: fontBold,
          fontItalic: fontItalic,
          fontMono: fontMono,
          emerald: emerald,
          emeraldLight: emeraldLight,
          ink: ink,
          inkMuted: inkMuted,
          codeBackground: codeBackground,
          ruleLine: ruleLine,
        )),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: '${doc.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}.pdf',
  );
}

// ── Page header / footer ──────────────────────────────────────────────────────

pw.Widget _buildPageHeader(
  VailDocument doc,
  pw.Font fontBold,
  pw.Font fontRegular,
  PdfColor emerald,
  PdfColor ink,
  PdfColor inkMuted,
  pw.Context ctx,
) {
  if (ctx.pageNumber == 1) {
    // Full branded bar on first page only
    return pw.Container(
      color: ink,
      padding: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 8, height: 8,
                decoration: pw.BoxDecoration(
                  color: emerald,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'VAIL AI',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColors.white,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '·  BY ADAKIN DIGITAL',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: PdfColor.fromInt(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          pw.Text(
            doc.terminalId,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 9,
              color: PdfColor.fromInt(0xFF21C45D),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
  // Minimal header on subsequent pages
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0))),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          doc.title,
          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: inkMuted),
        ),
        pw.Text(
          'VAIL AI',
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromInt(0xFF21C45D), letterSpacing: 1.5),
        ),
      ],
    ),
  );
}

pw.Widget _buildPageFooter(
  VailDocument doc,
  pw.Font fontRegular,
  PdfColor inkMuted,
  pw.Context ctx,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0))),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated by Vail AI  ·  ${doc.wordCountLabel}  ·  ${doc.readingTimeLabel}',
          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: inkMuted),
        ),
        pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: inkMuted),
        ),
      ],
    ),
  );
}

// ── Markdown block renderer ───────────────────────────────────────────────────

pw.Widget _renderBlock(
  _Block block, {
  required pw.Font fontRegular,
  required pw.Font fontBold,
  required pw.Font fontItalic,
  required pw.Font fontMono,
  required PdfColor emerald,
  required PdfColor emeraldLight,
  required PdfColor ink,
  required PdfColor inkMuted,
  required PdfColor codeBackground,
  required PdfColor ruleLine,
}) {
  switch (block.type) {
    case _BlockType.h1:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              block.text,
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: ink, lineSpacing: 3),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, width: 32, color: emerald),
          ],
        ),
      );

    case _BlockType.h2:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(
          block.text,
          style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColor.fromInt(0xFF21C45D), lineSpacing: 2),
        ),
      );

    case _BlockType.h3:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Text(
          block.text,
          style: pw.TextStyle(font: fontBold, fontSize: 12, color: ink, lineSpacing: 2),
        ),
      );

    case _BlockType.h4:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Text(
          block.text,
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: inkMuted),
        ),
      );

    case _BlockType.paragraph:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          _stripInlineMarkdown(block.text),
          style: pw.TextStyle(font: fontRegular, fontSize: 11, color: ink, lineSpacing: 5),
        ),
      );

    case _BlockType.listItem:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 16, bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 5, height: 5,
              margin: const pw.EdgeInsets.only(top: 4, right: 8),
              decoration: pw.BoxDecoration(color: emerald, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(
              child: pw.Text(
                _stripInlineMarkdown(block.text),
                style: pw.TextStyle(font: fontRegular, fontSize: 11, color: ink, lineSpacing: 4),
              ),
            ),
          ],
        ),
      );

    case _BlockType.orderedListItem:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 16, bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 20,
              child: pw.Text(
                '${block.index}.',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: emerald),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                _stripInlineMarkdown(block.text),
                style: pw.TextStyle(font: fontRegular, fontSize: 11, color: ink, lineSpacing: 4),
              ),
            ),
          ],
        ),
      );

    case _BlockType.blockquote:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: const pw.Border(left: pw.BorderSide(color: PdfColor.fromInt(0xFF21C45D), width: 3)),
            color: PdfColor.fromInt(0xFFF0FDF4),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: pw.Text(
            _stripInlineMarkdown(block.text),
            style: pw.TextStyle(font: fontItalic, fontSize: 11, color: inkMuted, lineSpacing: 4),
          ),
        ),
      );

    case _BlockType.codeBlock:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            color: codeBackground,
            border: pw.Border.all(color: ruleLine),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.all(14),
          child: pw.Text(
            block.text,
            style: pw.TextStyle(font: fontMono, fontSize: 9.5, color: ink, lineSpacing: 4),
          ),
        ),
      );

    case _BlockType.rule:
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 12),
        child: pw.Container(height: 1, color: ruleLine),
      );

    case _BlockType.spacer:
      return pw.SizedBox(height: 6);
  }
}

// ── Markdown parser ───────────────────────────────────────────────────────────

enum _BlockType { h1, h2, h3, h4, paragraph, listItem, orderedListItem, blockquote, codeBlock, rule, spacer }

class _Block {
  final _BlockType type;
  final String text;
  final int index; // for ordered list items
  const _Block(this.type, this.text, {this.index = 0});
}

List<_Block> _parseMarkdown(String content) {
  final blocks = <_Block>[];
  final lines = content.split('\n');
  bool inCodeBlock = false;
  final codeBuffer = StringBuffer();
  int orderedIndex = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Code fence
    if (trimmed.startsWith('```')) {
      if (inCodeBlock) {
        blocks.add(_Block(_BlockType.codeBlock, codeBuffer.toString().trimRight()));
        codeBuffer.clear();
        inCodeBlock = false;
      } else {
        inCodeBlock = true;
      }
      continue;
    }

    if (inCodeBlock) {
      if (codeBuffer.isNotEmpty) codeBuffer.write('\n');
      codeBuffer.write(line);
      continue;
    }

    if (trimmed.isEmpty) {
      orderedIndex = 0;
      blocks.add(const _Block(_BlockType.spacer, ''));
      continue;
    }

    if (trimmed.startsWith('#### ')) {
      blocks.add(_Block(_BlockType.h4, trimmed.substring(5).trim()));
    } else if (trimmed.startsWith('### ')) {
      blocks.add(_Block(_BlockType.h3, trimmed.substring(4).trim()));
    } else if (trimmed.startsWith('## ')) {
      blocks.add(_Block(_BlockType.h2, trimmed.substring(3).trim()));
    } else if (trimmed.startsWith('# ')) {
      blocks.add(_Block(_BlockType.h1, trimmed.substring(2).trim()));
    } else if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      blocks.add(const _Block(_BlockType.rule, ''));
    } else if (trimmed.startsWith('> ')) {
      blocks.add(_Block(_BlockType.blockquote, trimmed.substring(2).trim()));
    } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      orderedIndex = 0;
      blocks.add(_Block(_BlockType.listItem, trimmed.substring(2).trim()));
    } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      orderedIndex++;
      final text = trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '').trim();
      blocks.add(_Block(_BlockType.orderedListItem, text, index: orderedIndex));
    } else {
      blocks.add(_Block(_BlockType.paragraph, trimmed));
    }
  }

  // Flush any unclosed code block
  if (inCodeBlock && codeBuffer.isNotEmpty) {
    blocks.add(_Block(_BlockType.codeBlock, codeBuffer.toString().trimRight()));
  }

  // Collapse consecutive spacers
  final collapsed = <_Block>[];
  for (final b in blocks) {
    if (b.type == _BlockType.spacer && collapsed.isNotEmpty && collapsed.last.type == _BlockType.spacer) continue;
    collapsed.add(b);
  }

  return collapsed;
}

/// Strips inline markdown symbols (`**`, `*`, `_`, `` ` ``) for plain PDF text.
String _stripInlineMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
      .replaceAll(RegExp(r'__(.+?)__'), r'$1')
      .replaceAll(RegExp(r'_(.+?)_'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
}
