import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vail_app/core/constants/app_constants.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/data/models/api/chat/ui_component.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/chat/widgets/code_block.dart';
import 'package:vail_app/views/chat/widgets/dynamic_component_renderer.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';

class MessageBubble extends StatelessWidget {
  final ConversationMessage message;
  final int index;
  const MessageBubble({required this.message, required this.index, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.xs + 2),
      child: message.isFromUser ? _UserBubble(message: message) : _AssistantBubble(message: message),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final ConversationMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: message.formContext != null
              ? _FormContextCard(formContext: message.formContext!)
              : Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg + 4, vertical: VailTheme.md + 2),
                  decoration: BoxDecoration(
                    color: VailTheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(VailTheme.radiusLg), topRight: Radius.circular(VailTheme.radiusLg), bottomLeft: Radius.circular(VailTheme.radiusLg), bottomRight: Radius.circular(VailTheme.radiusSm)),
                    border: Border.all(color: VailTheme.ghostBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageBytes != null) Padding(padding: const EdgeInsets.only(bottom: VailTheme.sm), child: _AttachedImage(bytes: message.imageBytes!)),
                      SelectableText(message.content, style: VailTheme.body),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Styled card that replaces the raw form-submission text bubble.
/// Shows each field the user filled in as a label → value row.
/// An empty [formContext] map renders as a "Skipped" card with no rows.
class _FormContextCard extends StatelessWidget {
  final Map<String, String> formContext;
  const _FormContextCard({required this.formContext});

  @override
  Widget build(BuildContext context) {
    final entries = formContext.entries.where((e) => e.value.trim().isNotEmpty).toList();
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.md + 2, vertical: VailTheme.sm + 2),
      decoration: BoxDecoration(
        color: VailTheme.primaryContainer.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(VailTheme.radiusLg),
          topRight: Radius.circular(VailTheme.radiusLg),
          bottomLeft: Radius.circular(VailTheme.radiusLg),
          bottomRight: Radius.circular(VailTheme.radiusSm),
        ),
        border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 11, color: VailTheme.primary),
              const SizedBox(width: 4),
              Text(
                entries.isEmpty ? 'SKIPPED' : 'CONTEXT PROVIDED',
                style: VailTheme.micro.copyWith(color: VailTheme.primary, letterSpacing: 1.2),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: VailTheme.xs + 1),
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key}  ', style: VailTheme.caption.copyWith(color: VailTheme.textMuted, fontSize: 10)),
                  Flexible(child: Text(e.value, style: VailTheme.caption.copyWith(fontSize: 10))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final ConversationMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: VailTheme.primaryContainer, shape: BoxShape.circle, border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2))),
          child: const Icon(Icons.eco_rounded, color: VailTheme.primary, size: 16),
        ),
        const SizedBox(width: VailTheme.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(left: 4, bottom: VailTheme.xs), child: Text(AppConstants.modelDisplayName(message.model ?? 'vail'), style: VailTheme.caption.copyWith(color: VailTheme.primary))),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                padding: const EdgeInsets.all(VailTheme.lg),
                decoration: BoxDecoration(
                  color: VailTheme.surfaceContainer,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(VailTheme.radiusSm), topRight: Radius.circular(VailTheme.radiusLg), bottomLeft: Radius.circular(VailTheme.radiusLg), bottomRight: Radius.circular(VailTheme.radiusLg)),
                  border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
                  boxShadow: VailTheme.aiCardGlow,
                ),
                child: _AssistantContent(message: message),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final ConversationMessage message;
  const _AssistantContent({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming && message.content.isEmpty) return const _TypingIndicator();
    // Guard: if the stream completed with no text content but UI components
    // are present, skip the empty MarkdownBody. If there are no components
    // either, show a fallback so the bubble is never silently blank.
    final hasContent = message.content.trim().isNotEmpty;
    final hasComponents = message.uiComponents.isNotEmpty;
    if (!hasContent && !hasComponents) {
      return Text('—', style: VailTheme.bodySmall.copyWith(color: VailTheme.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasContent)
          MarkdownBody(
            data: message.content,
            selectable: !message.isStreaming,
            styleSheet: _markdownStyles(context),
            builders: {'code': _CodeElementBuilder()},
            onTapLink: (text, href, title) {
              if (href != null) _confirmExternalLink(context, Uri.tryParse(href));
            },
          ),
        if (message.uiComponents.isNotEmpty)
          ...message.uiComponents.map((u) => DynamicComponentRenderer(
            component: u,
            isSubmitted: message.formSubmitted,
            onAction: (payload, formData) =>
                _handleComponentAction(context, payload, formData, u, message),
          )),
        if (message.isStreaming) ...[
          const SizedBox(height: VailTheme.sm),
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: VailTheme.primary)),
        ],
      ],
    );
  }

  void _handleComponentAction(
    BuildContext context,
    String payload,
    Map<String, String> formData,
    UIComponent component,
    ConversationMessage message,
  ) {
    final vm = context.read<ChatViewModel>();

    if (payload == 'open_doc_writer') {
      vm.markFormSubmitted();
      showNewDocumentSheet(context, initialPrompt: message.content);
      return;
    }

    // Build a label→value map for the summary card shown in place of the
    // raw context message. Only include fields the user actually filled in.
    final contextCard = {
      for (final field in component.inputFields)
        if (formData[field.key]?.trim().isNotEmpty == true)
          field.label: formData[field.key]!.trim(),
    };

    final text = _buildContextMessage(payload, formData, component.inputFields);
    vm.markFormSubmitted();
    vm.sendMessage(text, formContext: contextCard.isEmpty ? {} : contextCard);
  }

  String _buildContextMessage(
    String payload,
    Map<String, String> formData,
    List<UIField> fields,
  ) {
    // This instruction is appended to every form submission so the model
    // produces the final output immediately and does not loop back with
    // another form or further clarifying questions.
    const noLoop = ' Please respond with the final output now. Do not ask for more information.';

    final filledFields = fields
        .where((f) => formData[f.key]?.trim().isNotEmpty == true)
        .toList();
    if (filledFields.isEmpty) {
      // Skip or no data filled — just proceed with a direct instruction.
      return '$payload$noLoop';
    }
    final parts =
        filledFields.map((f) => '${f.label}: ${formData[f.key]!.trim()}').join(' | ');
    return 'Context — $parts\n\n$payload$noLoop';
  }

  void _confirmExternalLink(BuildContext context, Uri? uri) async {
    if (uri == null) return;
    final confirmed = await showVailDialog<bool>(
      context: context,
      title: 'External Link',
      body: Text('Open ${uri.toString()} in your browser?', style: VailTheme.bodySmall),
      actions: const [
        VailDialogAction(label: 'Cancel', value: false),
        VailDialogAction(label: 'Open', value: true, isPrimary: true),
      ],
    );
    if (confirmed == true) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  MarkdownStyleSheet _markdownStyles(BuildContext context) {
    return MarkdownStyleSheet(
      p: VailTheme.body,
      strong: VailTheme.body.copyWith(fontWeight: FontWeight.w700),
      code: VailTheme.inlineCode,
      codeblockDecoration: BoxDecoration(color: const Color(0xFF031109), border: Border.all(color: VailTheme.ghostBorder), borderRadius: BorderRadius.circular(VailTheme.radiusSm)),
      codeblockPadding: const EdgeInsets.all(VailTheme.md),
      blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: VailTheme.primary.withValues(alpha: 0.4), width: 3)), color: VailTheme.primaryContainer),
      listBullet: VailTheme.body.copyWith(color: VailTheme.primary),
    );
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final rawClass = element.attributes['class'] ?? '';
    final lang = rawClass.replaceAll('language-', '').trim();
    if (lang.isEmpty && !code.contains('\n')) return null;
    return Padding(padding: const EdgeInsets.symmetric(vertical: VailTheme.xs), child: CodeBlock(code: code.trimRight(), language: lang.isEmpty ? null : lang));
  }
}

class _AttachedImage extends StatelessWidget {
  final Uint8List bytes;
  const _AttachedImage({required this.bytes});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(VailTheme.radiusSm), child: Image.memory(bytes, fit: BoxFit.cover, width: 280));
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [_Dot(delay: Duration.zero), SizedBox(width: 5), _Dot(delay: Duration(milliseconds: 160)), SizedBox(width: 5), _Dot(delay: Duration(milliseconds: 320))]);
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
    _ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
    Future.delayed(widget.delay, () { if (mounted) _ctrl.repeat(reverse: true); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: VailTheme.primary, shape: BoxShape.circle)));
}
