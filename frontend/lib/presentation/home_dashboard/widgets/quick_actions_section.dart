import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'dart:ui';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: _buildGlassActionButton(
                  context,
                  "Scan Barcode",
                  "qr_code_scanner",
                  colorScheme.primary,
                  onScanBarcode,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildGlassActionButton(
                  context,
                  "Upload Image",
                  "photo_camera",
                  AppTheme.getSuccessColor(
                      theme.brightness == Brightness.light),
                  onUploadImage,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildGlassActionButton(
            context,
            "Chat with AI Assistant",
            "smart_toy",
            AppTheme.getWarningColor(theme.brightness == Brightness.light),
            onChatWithAI,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassActionButton(
    BuildContext context,
    String title,
    String iconName,
    Color color,
    VoidCallback onTap, {
    bool isFullWidth = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlowButton(
      glowColor: color,
      glowIntensity: isDark ? 0.2 : 0.1,
      borderRadius: 16.0,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: isFullWidth ? 8.h : 12.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ]
                    : [
                        color.withValues(alpha: 0.1),
                        color.withValues(alpha: 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? color.withValues(alpha: 0.35)
                    : color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: color,
                            shadows: isDark
                                ? AppTheme.textGlow(color, blur: 4)
                                : null,
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
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
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
      ),
    );
  }
}
