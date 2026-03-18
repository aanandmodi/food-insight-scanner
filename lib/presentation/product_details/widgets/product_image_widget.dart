import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String productName;

  const ProductImageWidget({
    super.key,
    this.imageUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.9),
            AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CustomImageWidget(
                imageUrl: imageUrl!,
                width: double.infinity,
                height: 40.h,
                fit: BoxFit.cover,
              )
            : Container(
                width: double.infinity,
                height: 40.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.lightTheme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      AppTheme.lightTheme.colorScheme.secondary
                          .withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'image',
                      size: 48,
                      color: AppTheme.lightTheme.colorScheme.primary
                          .withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No Image Available',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
