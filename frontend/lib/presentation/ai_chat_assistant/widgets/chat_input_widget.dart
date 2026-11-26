import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController textController;
  final Function(String) onSendMessage;
  final bool isLoading;

  const ChatInputWidget({
    super.key,
    required this.textController,
    required this.onSendMessage,
    this.isLoading = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.textController.text.trim().isNotEmpty;
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
      _hasText = widget.textController.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.textController.text.trim().isNotEmpty;
    if (_hasText != hasText) setState(() => _hasText = hasText);
  }

  void _sendMessage() {
    if (!_hasText || widget.isLoading) return;
    widget.onSendMessage(widget.textController.text.trim());
    widget.textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
                color: FoodInsightColors.outlineGray.withValues(alpha: .6))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
              controller: widget.textController,
              maxLength: 2000,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: FoodInsightTypography.body(size: 15),
              decoration: const InputDecoration(
                hintText: 'Ask about nutrition…',
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            )),
            IconButton.filled(
              tooltip: widget.isLoading ? 'Waiting for reply' : 'Send message',
              onPressed: _hasText && !widget.isLoading ? _sendMessage : null,
              style: IconButton.styleFrom(
                  backgroundColor: FoodInsightColors.primary),
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ]),
        ),
      ),
    );
  }
}
