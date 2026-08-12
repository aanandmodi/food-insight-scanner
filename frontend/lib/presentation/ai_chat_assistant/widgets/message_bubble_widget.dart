import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_design_system.dart';

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
                gradient: FoodInsightColors.healthyGradient,
                boxShadow: [
                  BoxShadow(
                    color: FoodInsightColors.scannerGreen.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 4.w,
              ),
            ),
            SizedBox(width: 2.w),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 75.w),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: isUser
                    ? FoodInsightColors.scannerGreen
                    : Colors.white,
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
                    color: isUser
                        ? FoodInsightColors.scannerGreen.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: FoodInsightTypography.body(
                        size: 14.5,
                        color: isUser
                            ? Colors.white
                            : FoodInsightColors.deepCharcoal,
                      ),
                      strong: FoodInsightTypography.body(
                        size: 14.5,
                        weight: FontWeight.w800,
                        color: isUser
                            ? Colors.white
                            : FoodInsightColors.deepCharcoal,
                      ),
                      listBullet: FoodInsightTypography.body(
                        size: 14.5,
                        color: isUser
                            ? Colors.white
                            : FoodInsightColors.deepCharcoal,
                      ),
                      tableHead: FoodInsightTypography.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: isUser
                            ? Colors.white
                            : FoodInsightColors.deepCharcoal,
                      ),
                      tableBody: FoodInsightTypography.body(
                        size: 13,
                        color: isUser
                            ? Colors.white
                            : FoodInsightColors.deepCharcoal,
                      ),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    _formatTime(timestamp),
                    style: FoodInsightTypography.caption(
                      size: 10,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : FoodInsightColors.midGray,
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
                color: FoodInsightColors.scannerGreenLight,
              ),
              child: Icon(
                Icons.person_rounded,
                color: FoodInsightColors.scannerGreen,
                size: 4.5.w,
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
