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
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        boxShadow: [
          BoxShadow(
            color: FoodInsightColors.embossedShadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: onBackPressed,
              child: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: FoodInsightRadius.smAll,
                  boxShadow: FoodInsightShadows.subtleCard,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: FoodInsightColors.deepCharcoal,
                  size: 5.w,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Container(
              width: 11.w,
              height: 11.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: FoodInsightColors.healthyGradient,
                boxShadow: [
                  BoxShadow(
                    color: FoodInsightColors.scannerGreen.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 5.5.w,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Insight AI',
                    style: FoodInsightTypography.heading(
                      size: 17,
                      weight: FontWeight.w800,
                      color: FoodInsightColors.deepCharcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.3.h),
                  Row(
                    children: [
                      Container(
                        width: 2.w,
                        height: 2.w,
                        decoration: BoxDecoration(
                          color: FoodInsightColors.scannerGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: FoodInsightColors.scannerGreen.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Online',
                        style: FoodInsightTypography.caption(
                          size: 11,
                          weight: FontWeight.w600,
                          color: FoodInsightColors.scannerGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                // Show more options
              },
              child: Container(
                padding: EdgeInsets.all(2.w),
                child: Icon(
                  Icons.more_vert_rounded,
                  color: FoodInsightColors.midGray,
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
