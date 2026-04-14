import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vail_app/core/keys/chat_keys.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

class ChatInput extends StatefulWidget {
  final bool enabled;

  /// Called with the trimmed message text and an optional attached image.
  final void Function(String input, {Uint8List? imageBytes}) onSend;

  final VoidCallback? onNewDocument;

  const ChatInput({
    required this.enabled,
    required this.onSend,
    this.onNewDocument,
    super.key,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _pendingImage;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _handleSend();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pendingImage = bytes);
  }

  void _clearImage() => setState(() => _pendingImage = null);

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    final image = _pendingImage;
    setState(() {
      _controller.clear();
      _pendingImage = null;
    });
    widget.onSend(text, imageBytes: image);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md,
        vertical: VailTheme.sm,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(top: BorderSide(color: VailTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview strip
            if (_pendingImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: VailTheme.sm),
                child: _ImagePreview(
                  bytes: _pendingImage!,
                  onRemove: _clearImage,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Image picker button
                _IconButton(
                  icon: Icons.image_outlined,
                  active: _pendingImage != null,
                  onTap: _pickImage,
                ),
                const SizedBox(width: VailTheme.sm),
                // Doc button
                if (widget.onNewDocument != null) ...[
                  _IconButton(
                    icon: Icons.article_outlined,
                    onTap: widget.onNewDocument!,
                  ),
                  const SizedBox(width: VailTheme.sm),
                ],
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: VailTheme.surfaceInput,
                      border: Border.all(color: VailTheme.border),
                      borderRadius: BorderRadius.circular(VailTheme.radiusMd),
                    ),
                    child: TextField(
                      key: ChatKeys.messageInput,
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      maxLines: 6,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      style: VailTheme.body,
                      decoration: InputDecoration(
                        hintText: 'Message Vail...',
                        hintStyle: VailTheme.body
                            .copyWith(color: VailTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: VailTheme.md,
                          vertical: VailTheme.sm + 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: VailTheme.sm),
                // Send button
                _SendButton(
                  key: ChatKeys.sendButton,
                  enabled: widget.enabled,
                  onTap: _handleSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _ImagePreview({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
            child: Image.memory(
              bytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          // Remove badge
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: VailTheme.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: VailTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? VailTheme.accentSubtle : VailTheme.surfaceInput,
          border: Border.all(
            color: active
                ? VailTheme.accent.withValues(alpha: 0.5)
                : VailTheme.border,
          ),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: active ? VailTheme.accent : VailTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? VailTheme.accent : VailTheme.textMuted,
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: enabled ? VailTheme.onAccent : VailTheme.background,
          size: 18,
        ),
      ),
    );
  }
}
