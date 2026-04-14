import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';
import 'package:vail_app/views/documents/document_editor_view.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';

/// Mobile documents UI — list of AI-produced documents with header.
/// Safe-area padding handled internally.
///
/// Rendered by [DocumentsView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [DocumentsView].
class DocumentsViewMobile extends StatelessWidget {
  const DocumentsViewMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DocumentsHeader(
          statusTop: MediaQuery.of(context).padding.top,
          onNewDocument: () => showNewDocumentSheet(context),
        ),
        Expanded(
          child: Selector<DocumentsViewModel, bool>(
            selector: (_, vm) => vm.isEmpty,
            builder: (context, isEmpty, _) => isEmpty
                ? _EmptyState(
                    onNewDocument: () => showNewDocumentSheet(context),
                  )
                : const _DocumentsList(),
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DocumentsHeader extends StatelessWidget {
  final double statusTop;
  final VoidCallback onNewDocument;

  const _DocumentsHeader({
    required this.statusTop,
    required this.onNewDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: statusTop + VailTheme.lg,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.lg,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documents', style: VailTheme.heading),
                SizedBox(height: 2),
                Text(
                  'AI-produced documents, ready to copy or share.',
                  style: VailTheme.bodySmall,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onNewDocument,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VailTheme.md,
                vertical: VailTheme.sm,
              ),
              decoration: BoxDecoration(
                color: VailTheme.accentSubtle,
                border: Border.all(
                    color: VailTheme.accent.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      color: VailTheme.accent, size: 14),
                  const SizedBox(width: VailTheme.xs),
                  Text(
                    'NEW',
                    style: VailTheme.mono.copyWith(color: VailTheme.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document list ─────────────────────────────────────────────────────────────

class _DocumentsList extends StatelessWidget {
  const _DocumentsList();

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentsViewModel>().documents;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: VailTheme.sm),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: VailTheme.lg,
        endIndent: VailTheme.lg,
      ),
      itemBuilder: (context, index) => _DocumentTile(
        doc: docs[index],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (routeCtx) => ChangeNotifierProvider.value(
              value: context.read<DocumentsViewModel>(),
              child: DocumentEditorView(document: docs[index]),
            ),
          ),
        ),
        onDelete: () =>
            context.read<DocumentsViewModel>().removeDocument(docs[index].id),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final VailDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: VailTheme.xl),
        color: VailTheme.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded,
            color: VailTheme.error, size: 20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.lg,
            vertical: VailTheme.md,
          ),
          child: Row(
            children: [
              _DocTypeBadge(title: doc.title),
              const SizedBox(width: VailTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: VailTheme.sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VailTheme.xs),
                    Row(
                      children: [
                        Text(doc.wordCountLabel, style: VailTheme.bodySmall),
                        const SizedBox(width: VailTheme.sm),
                        Text('·',
                            style: VailTheme.bodySmall
                                .copyWith(color: VailTheme.textMuted)),
                        const SizedBox(width: VailTheme.sm),
                        Text(
                          _relativeTime(doc.createdAt),
                          style: VailTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: VailTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DocTypeBadge extends StatelessWidget {
  final String title;

  const _DocTypeBadge({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VailTheme.accentSubtle,
        border: Border.all(color: VailTheme.accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.article_outlined,
        color: VailTheme.accent,
        size: 18,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewDocument;

  const _EmptyState({required this.onNewDocument});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VailTheme.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VailTheme.accentSubtle,
                border: Border.all(
                    color: VailTheme.accent.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(VailTheme.radiusMd),
              ),
              child: const Icon(
                Icons.article_outlined,
                color: VailTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(height: VailTheme.lg),
            Text(
              'No documents yet',
              style: VailTheme.body.copyWith(color: VailTheme.textSecondary),
            ),
            const SizedBox(height: VailTheme.sm),
            const Text(
              'Ask Vail to write a report, proposal, email,\nor any other document — it appears here.',
              style: VailTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xl),
            GestureDetector(
              onTap: onNewDocument,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VailTheme.xl,
                  vertical: VailTheme.sm + 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: VailTheme.accent),
                  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                ),
                child: Text(
                  'NEW DOCUMENT',
                  style: VailTheme.mono.copyWith(color: VailTheme.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
