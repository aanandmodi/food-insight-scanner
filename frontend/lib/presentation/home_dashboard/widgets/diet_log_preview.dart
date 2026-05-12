import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diet Log',
                  style: FoodInsightTypography.heading(
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'View All →',
                    style: FoodInsightTypography.caption(
                      size: 13,
                      weight: FontWeight.w600,
                      color: FoodInsightColors.infoBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recentEntries.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: recentEntries
                        .take(3)
                        .map((entry) => _buildLogEntry(entry))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FoodInsightColors.cream,
        borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(
          color: FoodInsightColors.embossedShadow.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Food image
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: FoodInsightRadius.smAll,
              color: FoodInsightColors.warmWhite,
            ),
            child: ClipRRect(
              borderRadius: FoodInsightRadius.smAll,
              child: CustomImageWidget(
                imageUrl: entry['image'] as String? ?? '',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
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
                  entry['name'] as String? ?? 'Unknown Food',
                  style: FoodInsightTypography.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: FoodInsightColors.deepCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${entry['calories'] ?? 0} kcal',
                      style: FoodInsightTypography.caption(
                        size: 11,
                        weight: FontWeight.w600,
                        color: FoodInsightColors.infoBlue,
                      ),
                    ),
                    if ((entry['time'] as String?)?.isNotEmpty == true) ...[
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
                        entry['time'] as String? ?? '',
                        style: FoodInsightTypography.caption(
                          size: 11,
                          color: FoodInsightColors.midGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: FoodInsightColors.midGray,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.restaurant_rounded,
              color: FoodInsightColors.midGray.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              'No entries yet',
              style: FoodInsightTypography.body(
                weight: FontWeight.w600,
                color: FoodInsightColors.midGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start logging your meals to track progress',
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
