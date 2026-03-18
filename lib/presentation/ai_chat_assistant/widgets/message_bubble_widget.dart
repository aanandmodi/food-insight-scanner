import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class MessageBubbleWidget extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.5.h, horizontal: 4.w),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightTheme.primaryColor,
                    AppTheme.lightTheme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomIconWidget(
                iconName: 'smart_toy',
                color: Colors.white,
                size: 4.w,
              ),
            ),
            SizedBox(width: 2.w),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 75.w),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.lightTheme.primaryColor
                    : AppTheme.lightTheme.colorScheme.surface
                        .withOpacity(0.9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.w),
                  topRight: Radius.circular(4.w),
                  bottomLeft:
                      isUser ? Radius.circular(4.w) : Radius.circular(1.w),
                  bottomRight:
                      isUser ? Radius.circular(1.w) : Radius.circular(4.w),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: !isUser
                    ? Border.all(
                        color: AppTheme.lightTheme.colorScheme.outline
                            .withOpacity(0.2),
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? Colors.white
                            : AppTheme.lightTheme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    _formatTime(timestamp),
                    style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                      color: isUser
                          ? Colors.white.withOpacity(0.7)
                          : AppTheme.lightTheme.colorScheme.onSurface
                              .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 2.w),
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.lightTheme.colorScheme.secondary,
              ),
              child: CustomIconWidget(
                iconName: 'person',
                color: Colors.white,
                size: 4.w,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}