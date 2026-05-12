import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController textController;
  final Function(String) onSendMessage;
  final Function(String) onVoiceMessage;
  final bool isLoading;

  const ChatInputWidget({
    super.key,
    required this.textController,
    required this.onSendMessage,
    required this.onVoiceMessage,
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
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = widget.textController.text.trim().isNotEmpty;
    });
  }

  void _sendMessage() {
    if (widget.textController.text.trim().isNotEmpty && !widget.isLoading) {
      widget.onSendMessage(widget.textController.text.trim());
      widget.textController.clear();
    }
  }

  void _handleVoiceTap() {
    // Voice recording has been removed to eliminate the `record` package
    // dependency and its RECORD_AUDIO permission requirement.
    // Show a snackbar informing the user.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice input is coming soon!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.textController,
                        enabled: !widget.isLoading,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Ask about nutrition, ingredients...',
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    if (!_hasText)
                      GestureDetector(
                        onTap: _handleVoiceTap,
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          child: CustomIconWidget(
                            iconName: 'mic',
                            color: Theme.of(context).colorScheme.primary,
                            size: 5.w,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 2.w),
            GestureDetector(
              onTap: widget.isLoading ? null : _sendMessage,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  gradient:
                      _hasText && !widget.isLoading ? AppTheme.primaryGradient : null,
                  color: _hasText && !widget.isLoading
                      ? null
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: widget.isLoading
                    ? SizedBox(
                        width: 4.w,
                        height: 4.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      )
                    : CustomIconWidget(
                        iconName: 'send',
                        color: _hasText
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.5),
                        size: 5.w,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
