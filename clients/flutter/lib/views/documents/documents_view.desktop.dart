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

class DocumentsViewDesktop extends StatelessWidget {
  const DocumentsViewDesktop({super.key});

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
    return Column(
      children: [
        _DesktopToolbar(onNewDocument: () => _openNewDoc(context)),
        Expanded(
          child: Selector<DocumentsViewModel, bool>(
            selector: (_, vm) => vm.isEmpty,
            builder: (context, isEmpty, _) => isEmpty
                ? DocsEmptyState(onNewDocument: () => _openNewDoc(context))
                : const _DocumentsList(),
          ),
        ),
      ],
    );
  }
}

class _DesktopToolbar extends StatelessWidget {
  final VoidCallback onNewDocument;
  const _DesktopToolbar({required this.onNewDocument});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
      child: Row(
        children: [
          Text('AI-produced documents, ready to copy or share.', style: VailTheme.bodySmall),
          const Spacer(),
          GestureDetector(
            onTap: onNewDocument,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: VailTheme.md, vertical: VailTheme.sm),
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer,
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: VailTheme.primary, size: 14),
                  const SizedBox(width: VailTheme.xs),
                  Text('NEW DOCUMENT', style: VailTheme.label.copyWith(color: VailTheme.primary, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList();

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentsViewModel>().documents;
    return ListView.separated(
      padding: const EdgeInsets.all(VailTheme.lg),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: VailTheme.sm),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _DocumentRow(
          doc: doc,
          onTap: () {
            final vm = context.read<DocumentsViewModel>();
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (routeCtx) => ChangeNotifierProvider.value(
                value: vm,
                child: DocumentEditorView(document: doc),
              ),
            ));
          },
          onDelete: () => context.read<DocumentsViewModel>().removeDocument(doc.id),
        );
      },
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final VailDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentRow({required this.doc, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final preview = doc.contentPreview;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VailTheme.md),
        decoration: BoxDecoration(
          color: VailTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer.withValues(alpha: 0.12),
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.article_outlined, color: VailTheme.primary, size: 16),
            ),
            const SizedBox(width: VailTheme.md),
            // Title + preview
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: VailTheme.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: VailTheme.bodySmall.copyWith(
                        color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
                        fontSize: 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: VailTheme.lg),
            // Stats column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  doc.wordCountLabel,
                  style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  _relativeTime(doc.createdAt),
                  style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: VailTheme.md),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded, color: VailTheme.textMuted, size: 15),
            ),
          ],
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
