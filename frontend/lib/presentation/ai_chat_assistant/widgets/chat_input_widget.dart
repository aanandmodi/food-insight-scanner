import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_design_system.dart';

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
        color: FoodInsightColors.warmWhite,
        boxShadow: [
          BoxShadow(
            color: FoodInsightColors.embossedShadow.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: FoodInsightShadows.subtleCard,
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
                          hintStyle: FoodInsightTypography.body(
                            size: 14,
                            color: FoodInsightColors.midGray,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.5.h,
                          ),
                        ),
                        style: FoodInsightTypography.body(
                          size: 14,
                          color: FoodInsightColors.deepCharcoal,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    if (!_hasText)
                      GestureDetector(
                        onTap: _handleVoiceTap,
                        child: Padding(
                          padding: EdgeInsets.only(right: 3.w),
                          child: Icon(
                            Icons.mic_rounded,
                            color: FoodInsightColors.scannerGreen,
                            size: 5.5.w,
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
                  gradient: _hasText && !widget.isLoading
                      ? FoodInsightColors.healthyGradient
                      : null,
                  color: _hasText && !widget.isLoading
                      ? null
                      : FoodInsightColors.lightGray,
                  shape: BoxShape.circle,
                  boxShadow: _hasText && !widget.isLoading
                      ? [
                          BoxShadow(
                            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: widget.isLoading
                    ? Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FoodInsightColors.scannerGreen,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _hasText
                            ? Colors.white
                            : FoodInsightColors.midGray,
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
