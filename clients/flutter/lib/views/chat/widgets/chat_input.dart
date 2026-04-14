import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vail_app/core/keys/chat_keys.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Forest Sanctuary chat input bar.
///
/// Pill-shaped container with a glowing emerald send button.
/// Sits above the bottom nav, separated by a gradient fade.
class ChatInput extends StatefulWidget {
  final bool enabled;
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      // Gradient fade from background — matches Forest Sanctuary input area
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VailTheme.background.withValues(alpha: 0),
            VailTheme.background,
          ],
          stops: const [0.0, 0.35],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        VailTheme.lg,
        VailTheme.md,
        VailTheme.lg,
        bottomInset > 0
            ? VailTheme.md
            : bottomPad + VailTheme.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: VailTheme.sm),
              child: _ImagePreview(bytes: _pendingImage!, onRemove: _clearImage),
            ),
          // Pill input container
          Container(
            decoration: BoxDecoration(
              color: VailTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(VailTheme.radiusFull),
              border: Border.all(color: VailTheme.ghostBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attachment button
                _PillIconButton(
                  icon: Icons.add_circle_outline_rounded,
                  active: _pendingImage != null,
                  onTap: _pickImage,
                ),
                if (widget.onNewDocument != null)
                  _PillIconButton(
                    icon: Icons.description_outlined,
                    onTap: widget.onNewDocument!,
                  ),
                // Text field
                Expanded(
                  child: TextField(
                    key: ChatKeys.messageInput,
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    style: VailTheme.body.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message Vail...',
                      hintStyle: VailTheme.body.copyWith(
                        fontSize: 14,
                        color: VailTheme.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: VailTheme.sm,
                        vertical: VailTheme.md,
                      ),
                    ),
                  ),
                ),
                // Send button — glowing pill
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: _SendButton(
                    key: ChatKeys.sendButton,
                    enabled: widget.enabled,
                    onTap: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image preview strip ───────────────────────────────────────────────────────

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
            child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: VailTheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: VailTheme.ghostBorder),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: VailTheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon button inside pill ───────────────────────────────────────────────────

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _PillIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.sm + 2,
          vertical: VailTheme.md,
        ),
        child: Icon(
          icon,
          size: 22,
          color: active
              ? VailTheme.primary
              : VailTheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Send button ───────────────────────────────────────────────────────────────

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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? VailTheme.primary : VailTheme.surfaceContainerLow,
          shape: BoxShape.circle,
          boxShadow: enabled ? VailTheme.primaryGlow : null,
        ),
        child: Icon(
          Icons.send_rounded,
          color: enabled
              ? VailTheme.onPrimary
              : VailTheme.onSurfaceVariant.withValues(alpha: 0.3),
          size: 18,
        ),
      ),
    );
  }
}
