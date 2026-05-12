import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/skeuomorphic/skeu_card.dart';

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
                  'Recent Scans',
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
          ),
          const SizedBox(height: 12),
          recentScans.isEmpty
              ? _buildEmptyState()
              : SizedBox(
                  height: 18.h,
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
    final safetyStatus = scan['safetyStatus'] as String? ?? 'unknown';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/product-details', arguments: scan);
      },
      child: Container(
        width: 34.w,
        margin: EdgeInsets.only(right: 3.w),
        child: SkeuCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: FoodInsightRadius.smAll,
                    color: FoodInsightColors.cream,
                  ),
                  child: ClipRRect(
                    borderRadius: FoodInsightRadius.smAll,
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
              const SizedBox(height: 8),
              // Name
              Text(
                scan['name'] as String? ?? 'Unknown',
                style: FoodInsightTypography.caption(
                  size: 12,
                  weight: FontWeight.w700,
                  color: FoodInsightColors.deepCharcoal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Safety badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getSafetyColor(safetyStatus).withValues(alpha: 0.12),
                  borderRadius: FoodInsightRadius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _getSafetyColor(safetyStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getSafetyText(safetyStatus),
                      style: FoodInsightTypography.caption(
                        size: 9,
                        weight: FontWeight.w700,
                        color: _getSafetyColor(safetyStatus),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSafetyColor(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return FoodInsightColors.scannerGreen;
      case 'warning':
        return FoodInsightColors.warningAmber;
      case 'danger':
        return FoodInsightColors.healthRed;
      default:
        return FoodInsightColors.midGray;
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

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: SkeuCard(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: FoodInsightColors.midGray,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'No scans yet',
                style: FoodInsightTypography.body(
                  weight: FontWeight.w600,
                  color: FoodInsightColors.midGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start scanning to see your history',
                style: FoodInsightTypography.caption(
                  size: 12,
                  color: FoodInsightColors.midGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
