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
    if (isUser) {
      return Container(
        margin: EdgeInsets.only(top: 1.h, bottom: 1.h, left: 15.w, right: 4.w),
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: FoodInsightColors.scannerGreen,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(5.w),
              topRight: Radius.circular(5.w),
              bottomLeft: Radius.circular(5.w),
              bottomRight: Radius.circular(1.w),
            ),
            boxShadow: [
              BoxShadow(
                color: FoodInsightColors.scannerGreen.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: FoodInsightTypography.body(
              size: 15,
              color: Colors.white,
              weight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // AI Message Bubble
    return Container(
      margin: EdgeInsets.only(top: 1.h, bottom: 1.h, left: 4.w, right: 10.w),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            margin: EdgeInsets.only(top: 0.5.h, right: 3.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FoodInsightColors.healthyGradient,
              boxShadow: [
                BoxShadow(
                  color: FoodInsightColors.scannerGreen.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 4.5.w,
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(1.w),
                  topRight: Radius.circular(5.w),
                  bottomLeft: Radius.circular(5.w),
                  bottomRight: Radius.circular(5.w),
                ),
                border: Border.all(
                  color: FoodInsightColors.outlineGray.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: FoodInsightShadows.subtleCard,
              ),
              child: MarkdownBody(
                data: message,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: FoodInsightTypography.body(
                    size: 15,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                  strong: FoodInsightTypography.body(
                    size: 15,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                  listBullet: FoodInsightTypography.body(
                    size: 15,
                    color: FoodInsightColors.scannerGreen,
                    weight: FontWeight.w800,
                  ),
                  h1: FoodInsightTypography.heading(size: 20),
                  h2: FoodInsightTypography.heading(size: 18),
                  h3: FoodInsightTypography.heading(size: 16),
                  blockquote: FoodInsightTypography.body(
                    size: 14,
                    color: FoodInsightColors.midGray,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
