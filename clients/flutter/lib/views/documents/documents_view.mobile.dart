import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/documents/document_editor_view.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';
import 'package:vail_app/views/documents/widgets/docs_empty_state.dart';
import 'package:vail_app/views/settings/settings_viewmodel.dart';
import 'package:vail_app/views/upgrade/upgrade_sheet.dart';

class DocumentsViewMobile extends StatelessWidget {
  const DocumentsViewMobile({super.key});

  void _openNewDoc(BuildContext context) {
    if (!context.read<ChatViewModel>().isPro) {
      showUpgradeSheet(
        context,
        onProActivated: () {
          context.read<SettingsViewModel>().setIsPro(true);
          context.read<ChatViewModel>().refreshPlan();
          showNewDocumentSheet(context);
        },
      );
      return;
    }
    showNewDocumentSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentsViewModel>();
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Column(
        children: [
          _DocsHeader(statusTop: MediaQuery.of(context).padding.top),
          Expanded(
            child: vm.isEmpty
                ? DocsEmptyState(onNewDocument: () => _openNewDoc(context))
                : _DocsList(documents: vm.documents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewDoc(context),
        backgroundColor: VailTheme.primary,
        child: const Icon(Icons.add, color: VailTheme.onPrimary),
      ),
    );
  }
}

class _DocsHeader extends StatelessWidget {
  final double statusTop;
  const _DocsHeader({required this.statusTop});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(top: statusTop + VailTheme.lg, left: VailTheme.lg, right: VailTheme.lg, bottom: VailTheme.lg),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
    child: Row(children: [
      Text('Library', style: VailTheme.heading),
      const Spacer(),
      const Icon(Icons.search_rounded, color: VailTheme.onSurfaceVariant, size: 20),
    ]),
  );
}

class _DocsList extends StatelessWidget {
  final List<VailDocument> documents;
  const _DocsList({required this.documents});
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(VailTheme.lg),
    itemCount: documents.length,
    separatorBuilder: (_, __) => const SizedBox(height: VailTheme.md),
    itemBuilder: (ctx, idx) => _DocCard(document: documents[idx]),
  );
}

class _DocCard extends StatelessWidget {
  final VailDocument document;
  const _DocCard({required this.document, super.key});

  void _open(BuildContext context) {
    if (!context.read<ChatViewModel>().isPro) {
      showUpgradeSheet(
        context,
        onProActivated: () {
          context.read<SettingsViewModel>().setIsPro(true);
          context.read<ChatViewModel>().refreshPlan();
          _pushEditor(context);
        },
      );
      return;
    }
    _pushEditor(context);
  }

  void _pushEditor(BuildContext context) {
    // DocumentEditorView uses Consumer<DocumentsViewModel> — must pass the
    // existing VM into the new route's provider scope.
    final vm = context.read<DocumentsViewModel>();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (routeCtx) => ChangeNotifierProvider.value(
          value: vm,
          child: DocumentEditorView(document: document),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = document.contentPreview;
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(VailTheme.md + 2),
        decoration: BoxDecoration(
          color: VailTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + title + arrow
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: VailTheme.primaryContainer.withValues(alpha: 0.12),
                    border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.article_outlined, color: VailTheme.primary, size: 16),
                ),
                const SizedBox(width: VailTheme.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: VailTheme.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        document.terminalId,
                        style: VailTheme.micro.copyWith(color: VailTheme.primary.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VailTheme.xs),
                const Icon(Icons.chevron_right_rounded, size: 16, color: VailTheme.textMuted),
              ],
            ),
            // Preview text
            if (preview.isNotEmpty) ...[
              const SizedBox(height: VailTheme.sm + 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VailTheme.sm),
                decoration: BoxDecoration(
                  color: VailTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                  border: Border.all(color: VailTheme.ghostBorder.withValues(alpha: 0.5)),
                ),
                child: Text(
                  preview,
                  style: VailTheme.bodySmall.copyWith(
                    color: VailTheme.onSurfaceVariant.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // Metadata row
            const SizedBox(height: VailTheme.sm),
            Row(
              children: [
                _MetaChip(label: document.wordCountLabel, icon: Icons.notes_rounded),
                const SizedBox(width: VailTheme.xs),
                _MetaChip(label: document.readingTimeLabel, icon: Icons.schedule_rounded),
                const Spacer(),
                Text(
                  _formatDate(document.createdAt),
                  style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: VailTheme.textMuted),
      const SizedBox(width: 3),
      Text(label, style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 9)),
    ],
  );
}
