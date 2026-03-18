import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = widget.textController.text.trim().isNotEmpty;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(),
            path: 'voice_message.m4a');
        setState(() {
          _isRecording = true;
        });
      } else {
        await Permission.microphone.request();
      }
    } catch (e) {
      // Handle recording error silently
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        widget.onVoiceMessage('Voice message recorded');
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _sendMessage() {
    if (widget.textController.text.trim().isNotEmpty && !widget.isLoading) {
      widget.onSendMessage(widget.textController.text.trim());
      widget.textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6.w),
                  border: Border.all(
                    color: AppTheme.lightTheme.colorScheme.outline
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
                          hintStyle: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                        ),
                        style: AppTheme.lightTheme.textTheme.bodyMedium,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _hasText
                          ? null
                          : (_isRecording ? _stopRecording : _startRecording),
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        child: CustomIconWidget(
                          iconName: _hasText
                              ? 'keyboard'
                              : (_isRecording ? 'stop' : 'mic'),
                          color: _isRecording
                              ? Colors.red
                              : AppTheme.lightTheme.colorScheme.primary,
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
                  color: _hasText && !widget.isLoading
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline
                          .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: widget.isLoading
                    ? SizedBox(
                        width: 4.w,
                        height: 4.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.lightTheme.colorScheme.surface,
                          ),
                        ),
                      )
                    : CustomIconWidget(
                        iconName: 'send',
                        color: _hasText
                            ? AppTheme.lightTheme.colorScheme.surface
                            : AppTheme.lightTheme.colorScheme.onSurface
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
