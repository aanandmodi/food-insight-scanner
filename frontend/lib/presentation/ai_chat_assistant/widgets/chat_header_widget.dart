import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_design_system.dart';

class ChatHeaderWidget extends StatelessWidget {
  final VoidCallback onBackPressed;

  const ChatHeaderWidget({
    super.key,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 4.w, right: 4.w, top: MediaQuery.of(context).padding.top + 1.h, bottom: 1.5.h),
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        border: Border(
          bottom: BorderSide(
            color: FoodInsightColors.outlineGray.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBackPressed,
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: FoodInsightRadius.smAll,
                border: Border.all(
                  color: FoodInsightColors.outlineGray.withValues(alpha: 0.8),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: FoodInsightColors.deepCharcoal,
                size: 6.w,
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FoodInsightColors.healthyGradient,
              boxShadow: [
                BoxShadow(
                  color: FoodInsightColors.scannerGreen.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 5.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Nutritionist',
                  style: FoodInsightTypography.heading(
                    size: 17,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 1.5.w,
                      height: 1.5.w,
                      decoration: const BoxDecoration(
                        color: FoodInsightColors.scannerGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Text(
                      'Always active',
                      style: FoodInsightTypography.caption(
                        size: 13,
                        color: FoodInsightColors.scannerGreen,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
