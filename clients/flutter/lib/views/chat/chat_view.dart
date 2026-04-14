import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_dialog.dart';
import 'package:vail_app/views/chat/chat_view.desktop.dart';
import 'package:vail_app/views/chat/chat_view.mobile.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/documents/new_document_sheet.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';

/// Entry point for the chat feature.
///
/// Thin [ScreenTypeLayout.builder] wrapper — all UI concerns are in:
///   [ChatViewMobile]  — lib/views/chat/chat_view.mobile.dart
///   [ChatViewDesktop] — lib/views/chat/chat_view.desktop.dart
///
/// Business logic that applies to both platforms (doc intent detection,
/// send interception) lives here and is passed down as callbacks.
class ChatView extends StatelessWidget {
  final void Function(int) onSwitchTab;

  const ChatView({required this.onSwitchTab, super.key});

  /// Intercepts the send action to check for document-writing intent.
  ///
  /// If the message looks like a doc request, asks the user whether they'd
  /// like Doc Writer. On consent the sheet opens pre-filled. On decline
  /// (or no intent detected) the message is sent normally.
  Future<void> _handleSend(
    BuildContext context,
    String input, {
    Uint8List? imageBytes,
  }) async {
    if (ChatViewModel.detectsDocIntent(input)) {
      final choice = await showVailDialog<_DocPromptChoice>(
        context: context,
        title: 'DOC WRITER',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'It looks like you want to write something. Would you like to use the Doc Writer for a richer output?',
              style: VailTheme.body.copyWith(color: VailTheme.textSecondary),
            ),
            const SizedBox(height: VailTheme.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VailTheme.md),
              decoration: BoxDecoration(
                color: VailTheme.background,
                border: Border.all(color: VailTheme.border),
                borderRadius: BorderRadius.circular(VailTheme.radiusSm),
              ),
              child: Text(
                input.length > 80 ? '${input.substring(0, 77)}…' : input,
                style: VailTheme.mono.copyWith(
                  color: VailTheme.textSecondary,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: const [
          VailDialogAction(
            label: 'SEND NORMALLY',
            value: _DocPromptChoice.sendNormally,
          ),
          VailDialogAction(
            label: 'DOC WRITER',
            value: _DocPromptChoice.useDocWriter,
            isPrimary: true,
          ),
        ],
      );

      if (!context.mounted) return;

      if (choice == _DocPromptChoice.useDocWriter) {
        showNewDocumentSheet(context, initialPrompt: input);
        return;
      }
      if (choice == null) return;
    }

    if (context.mounted) {
      await context.read<ChatViewModel>().sendMessage(input, imageBytes: imageBytes);
      // Silently refresh the sessions list so the updated/new session surfaces
      // at the top of both the sidebar and history tab without a spinner.
      if (context.mounted) {
        context.read<SessionsViewModel>().silentRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (ctx) => ChatViewMobile(
        onSwitchTab: onSwitchTab,
        onSend: (input, {imageBytes}) =>
            _handleSend(ctx, input, imageBytes: imageBytes),
      ),
      desktop: (ctx) => ChatViewDesktop(
        onSwitchTab: onSwitchTab,
        onSend: (input, {imageBytes}) =>
            _handleSend(ctx, input, imageBytes: imageBytes),
      ),
    );
  }
}

// ── Doc intent choice ─────────────────────────────────────────────────────────

enum _DocPromptChoice { useDocWriter, sendNormally }
