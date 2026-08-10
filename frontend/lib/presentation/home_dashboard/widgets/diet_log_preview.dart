import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';

class DietLogPreview extends StatelessWidget {
  final List<Map<String, dynamic>> recentEntries;
  final VoidCallback onViewAll;

  const DietLogPreview({
    super.key,
    required this.recentEntries,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: SkeuCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: FoodInsightColors.purpleAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DIET LOG PREVIEW',
                      style: FoodInsightTypography.smallCaps(
                        size: 11,
                        weight: FontWeight.w900,
                        color: FoodInsightColors.deepCharcoal.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: FoodInsightTypography.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: FoodInsightColors.infoBlue,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: FoodInsightColors.infoBlue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recentEntries.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: List.generate(
                      recentEntries.length > 3 ? 3 : recentEntries.length,
                      (index) {
                        final entry = recentEntries[index];
                        return _buildLogEntry(context, entry, index);
                      },
                    ),
                  ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildLogEntry(BuildContext context, Map<String, dynamic> entry, int index) {
    final name = entry['name'] as String? ?? 'Unknown Food';
    final calories = (entry['calories'] as num?)?.toInt() ?? 0;
    final timeStr = entry['time'] as String? ?? '';
    final imageUrl = entry['image'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(
          color: FoodInsightColors.lightGray.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Food Image with premium skeuomorphic frame
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: FoodInsightRadius.smAll,
              color: FoodInsightColors.warmWhite,
              border: Border.all(
                color: FoodInsightColors.lightGray.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: FoodInsightRadius.smAll,
              child: imageUrl.isNotEmpty
                  ? CustomImageWidget(
                      imageUrl: imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 20,
                        color: FoodInsightColors.midGray.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: FoodInsightTypography.body(
                    size: 14,
                    weight: FontWeight.w800,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$calories kcal',
                      style: FoodInsightTypography.caption(
                        size: 11,
                        weight: FontWeight.w700,
                        color: FoodInsightColors.infoBlue,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: FoodInsightColors.midGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: FoodInsightTypography.caption(
                          size: 11,
                          weight: FontWeight.w500,
                          color: FoodInsightColors.midGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: FoodInsightColors.midGray.withValues(alpha: 0.6),
            size: 20,
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: 300.ms,
          delay: (index * 60).ms,
        );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: FoodInsightColors.lightGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: FoodInsightColors.midGray,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No meal logged today',
              style: FoodInsightTypography.body(
                size: 15,
                weight: FontWeight.w800,
                color: FoodInsightColors.midGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Log your meals to check macros and calorie limits',
              style: FoodInsightTypography.caption(
                size: 12,
                color: FoodInsightColors.midGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
