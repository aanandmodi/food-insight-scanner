import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_bounce_button.dart';

class RecentScansSection extends StatelessWidget {
  final List<Map<String, dynamic>> recentScans;
  final VoidCallback onViewAll;

  const RecentScansSection({
    super.key,
    required this.recentScans,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Scans",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    "View All",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          recentScans.isEmpty
              ? _buildEmptyState(context)
              : SizedBox(
                  height: 20.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    itemCount: recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = recentScans[index];
                      return _buildScanCard(context, scan);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildScanCard(BuildContext context, Map<String, dynamic> scan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return CustomBounceButton(
      onTap: () {
        Navigator.pushNamed(context, '/product-details', arguments: scan);
      },
      child: Container(
        width: 35.w,
        margin: EdgeInsets.only(right: 3.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: isDark
                  ? AppTheme.glassmorphicDecoration(borderRadius: 16)
                  : BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              child: Padding(
                padding: EdgeInsets.all(3.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : colorScheme.surfaceContainerHighest,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Hero(
                            tag: 'scan_${scan['id']}',
                            child: CustomImageWidget(
                              imageUrl: scan['image'] as String? ?? '',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan['name'] as String? ?? 'Unknown Product',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Row(
                            children: [
                              _buildSafetyIndicator(
                                context,
                                scan['safetyStatus'] as String? ?? 'unknown',
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  _getSafetyText(
                                      scan['safetyStatus'] as String? ??
                                          'unknown'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _getSafetyColor(
                                      context,
                                      scan['safetyStatus'] as String? ??
                                          'unknown',
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyIndicator(BuildContext context, String status) {
    final color = _getSafetyColor(context, status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Color _getSafetyColor(BuildContext context, String status) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    switch (status.toLowerCase()) {
      case 'safe':
        return AppTheme.getSuccessColor(isLight);
      case 'warning':
        return AppTheme.getWarningColor(isLight);
      case 'danger':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getSafetyText(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return 'Safe';
      case 'warning':
        return 'Caution';
      case 'danger':
        return 'Avoid';
      default:
        return 'Unknown';
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 20.h,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: isDark
                ? AppTheme.glassmorphicDecoration(borderRadius: 16)
                : BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'qr_code_scanner',
                    size: 8.w,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    "No scans yet",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    "Start scanning to see your history",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
