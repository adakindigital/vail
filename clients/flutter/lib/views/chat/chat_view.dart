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

class ChatView extends StatelessWidget {
  final void Function(int) onSwitchTab;
  const ChatView({required this.onSwitchTab, super.key});

  Future<void> _handleSend(BuildContext context, String input, {Uint8List? imageBytes}) async {
    if (ChatViewModel.detectsDocIntent(input)) {
      final choice = await showVailDialog<_DocPromptChoice>(
        context: context,
        title: 'DOC WRITER',
        body: Text('Would you like to use the Doc Writer for a richer output?', style: VailTheme.body),
        actions: const [
          VailDialogAction(label: 'SEND NORMALLY', value: _DocPromptChoice.sendNormally),
          VailDialogAction(label: 'DOC WRITER', value: _DocPromptChoice.useDocWriter, isPrimary: true),
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
      if (context.mounted) context.read<SessionsViewModel>().silentRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (ctx) => ChatViewMobile(onSwitchTab: onSwitchTab, onSend: (input, {imageBytes}) => _handleSend(ctx, input, imageBytes: imageBytes)),
      desktop: (ctx) => ChatViewDesktop(onSwitchTab: onSwitchTab, onSend: (input, {imageBytes}) => _handleSend(ctx, input, imageBytes: imageBytes)),
    );
  }
}

enum _DocPromptChoice { useDocWriter, sendNormally }
