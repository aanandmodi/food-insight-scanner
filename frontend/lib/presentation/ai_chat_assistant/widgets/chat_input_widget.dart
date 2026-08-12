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
      padding: EdgeInsets.only(left: 4.w, right: 4.w, top: 1.5.h, bottom: MediaQuery.of(context).padding.bottom + 1.h),
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        border: Border(
          top: BorderSide(
            color: FoodInsightColors.outlineGray.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.w),
                border: Border.all(
                  color: FoodInsightColors.outlineGray.withValues(alpha: 0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: TextField(
                        controller: widget.textController,
                        enabled: !widget.isLoading,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: FoodInsightTypography.body(size: 15),
                        decoration: InputDecoration(
                          hintText: 'Ask about nutrition...',
                          hintStyle: FoodInsightTypography.body(
                            size: 15,
                            color: FoodInsightColors.midGray,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                        ),
                      ),
                    ),
                  ),
                  if (!_hasText)
                    IconButton(
                      icon: Icon(
                        Icons.mic_rounded,
                        color: FoodInsightColors.midGray,
                        size: 6.w,
                      ),
                      onPressed: _handleVoiceTap,
                    ),
                  if (_hasText)
                    Container(
                      margin: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: FoodInsightColors.scannerGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: widget.isLoading
                            ? SizedBox(
                                width: 5.w,
                                height: 5.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 5.w,
                              ),
                        onPressed: widget.isLoading ? null : _sendMessage,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
