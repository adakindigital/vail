import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/documents/document_editor_view.dart';
import 'package:vail_app/views/documents/documents_viewmodel.dart';

/// Bottom sheet for composing a new document generation request.
///
/// Shared between [DocumentsView] and [ChatView]. Pass [DocumentsViewModel]
/// into scope before showing (both views share the same MultiProvider).
///
/// On GENERATE: sheet dismisses, [DocumentEditorView] is pushed immediately
/// so the user sees the document stream in live.
class NewDocumentSheet extends StatefulWidget {
  /// Pre-fills the prompt field. Passed when the user triggers Doc Writer
  /// from the chat interface with an existing message.
  final String? initialPrompt;

  const NewDocumentSheet({this.initialPrompt, super.key});

  @override
  State<NewDocumentSheet> createState() => _NewDocumentSheetState();
}

class _NewDocumentSheetState extends State<NewDocumentSheet> {
  late final TextEditingController _promptCtrl;
  late String _selectedType;
  bool _generating = false;

  static const _types = ['Report', 'Proposal', 'Summary', 'Email', 'Brief', 'Custom'];

  /// Infers the best doc type pill from the prompt text.
  static String _inferType(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('email')) return 'Email';
    if (lower.contains('report')) return 'Report';
    if (lower.contains('proposal')) return 'Proposal';
    if (lower.contains('summary') || lower.contains('summar')) return 'Summary';
    if (lower.contains('brief')) return 'Brief';
    return 'Custom';
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPrompt ?? '';
    _promptCtrl = TextEditingController(text: initial);
    _selectedType = initial.isNotEmpty ? _inferType(initial) : 'Custom';
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _generating = true);

    final vm = context.read<DocumentsViewModel>();

    // Dismiss the sheet first, then push the editor immediately so the
    // user sees live streaming content as soon as the sheet closes.
    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeCtx) => ChangeNotifierProvider.value(
          value: vm,
          child: const DocumentEditorView(),
        ),
      ),
    );

    // Generation runs in background; DocumentEditorView watches vm state.
    await vm.generateDocument(prompt: prompt, docType: _selectedType);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: VailTheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VailTheme.radiusLg),
          ),
          border: Border(top: BorderSide(color: VailTheme.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg,
              VailTheme.lg,
              VailTheme.lg,
              VailTheme.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: VailTheme.lg),
                    decoration: BoxDecoration(
                      color: VailTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'NEW DOCUMENT',
                  style: VailTheme.mono.copyWith(color: VailTheme.accent),
                ),
                const SizedBox(height: VailTheme.md),
                // Document type pills
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _types.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: VailTheme.sm),
                    itemBuilder: (context, index) {
                      final type = _types[index];
                      final isActive = type == _selectedType;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: VailTheme.md,
                            vertical: VailTheme.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? VailTheme.accentSubtle
                                : Colors.transparent,
                            border: Border.all(
                              color: isActive
                                  ? VailTheme.accent
                                  : VailTheme.border,
                            ),
                            borderRadius:
                                BorderRadius.circular(VailTheme.radiusSm),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: VailTheme.mono.copyWith(
                              color: isActive
                                  ? VailTheme.accent
                                  : VailTheme.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: VailTheme.md),
                // Prompt input
                Container(
                  decoration: BoxDecoration(
                    color: VailTheme.surfaceInput,
                    border: Border.all(color: VailTheme.border),
                    borderRadius: BorderRadius.circular(VailTheme.radiusMd),
                  ),
                  child: TextField(
                    controller: _promptCtrl,
                    maxLines: 4,
                    minLines: 2,
                    autofocus: true,
                    style: VailTheme.body,
                    decoration: InputDecoration(
                      hintText: _selectedType == 'Custom'
                          ? 'What should Vail write?'
                          : 'What is this ${_selectedType.toLowerCase()} about?',
                      hintStyle:
                          VailTheme.body.copyWith(color: VailTheme.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(VailTheme.md),
                    ),
                  ),
                ),
                const SizedBox(height: VailTheme.md),
                // Generate button
                GestureDetector(
                  onTap: _generating ? null : _generate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: VailTheme.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: _generating
                          ? VailTheme.accentSubtle
                          : VailTheme.accent,
                      borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _generating ? 'WRITING…' : 'GENERATE',
                      style: VailTheme.mono.copyWith(
                        color: _generating
                            ? VailTheme.accent
                            : VailTheme.onAccent,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [NewDocumentSheet] as a modal bottom sheet.
///
/// Pass [initialPrompt] to pre-fill the prompt field and auto-select the
/// document type — used when the chat interface detects a document request.
void showNewDocumentSheet(BuildContext context, {String? initialPrompt}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => ChangeNotifierProvider.value(
      value: context.read<DocumentsViewModel>(),
      child: NewDocumentSheet(initialPrompt: initialPrompt),
    ),
  );
}
