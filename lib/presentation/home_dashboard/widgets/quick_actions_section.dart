import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onUploadImage;
  final VoidCallback onChatWithAI;

  const QuickActionsSection({
    super.key,
    required this.onScanBarcode,
    required this.onUploadImage,
    required this.onChatWithAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  "Scan Barcode",
                  "qr_code_scanner",
                  AppTheme.lightTheme.colorScheme.primary,
                  onScanBarcode,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildActionButton(
                  context,
                  "Upload Image",
                  "photo_camera",
                  AppTheme.getSuccessColor(true),
                  onUploadImage,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildActionButton(
            context,
            "Chat with AI Assistant",
            "smart_toy",
            AppTheme.getWarningColor(true),
            onChatWithAI,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String iconName,
    Color color,
    VoidCallback onTap, {
    bool isFullWidth = false,
  }) {
    return Container(
      height: isFullWidth ? 8.h : 12.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: isFullWidth
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomIconWidget(
                        iconName: iconName,
                        size: 6.w,
                        color: color,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        title,
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomIconWidget(
                        iconName: iconName,
                        size: 8.w,
                        color: color,
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        title,
                        style:
                            AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
