import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ChatHeaderWidget extends StatelessWidget {
  final VoidCallback onBackPressed;

  const ChatHeaderWidget({
    super.key,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
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
                child: CustomIconWidget(
                  iconName: 'arrow_back',
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  size: 6.w,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightTheme.colorScheme.primary,
                    AppTheme.lightTheme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomIconWidget(
                iconName: 'smart_toy',
                color: Colors.white,
                size: 6.w,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NutriBot Assistant',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Container(
                        width: 2.w,
                        height: 2.w,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Online',
                        style:
                            AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
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
                child: CustomIconWidget(
                  iconName: 'more_vert',
                  color: AppTheme.lightTheme.colorScheme.onSurface,
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