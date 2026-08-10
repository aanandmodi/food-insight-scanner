import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      margin: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: FoodInsightColors.infoBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECENT SCANS',
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
                        'See All',
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
          ),
          const SizedBox(height: 12),
          recentScans.isEmpty
              ? _buildEmptyState()
              : _buildScansList(),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  /// Vertical list of scan items inside a white card
  Widget _buildScansList() {
    final listItems = recentScans.length > 4 ? recentScans.sublist(0, 4) : recentScans;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: SkeuCard(
        padding: EdgeInsets.zero,
        borderRadius: 24,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: listItems.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: FoodInsightColors.lightGray.withValues(alpha: 0.4),
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final scan = listItems[index];
              return _buildScanListItem(context, scan, index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScanListItem(BuildContext context, Map<String, dynamic> scan, int index) {
    final safetyStatus = scan['safetyStatus'] as String? ?? 'unknown';
    final name = scan['name'] as String? ?? 'Unknown';
    final imageUrl = scan['image'] as String? ?? '';
    final brand = scan['brand'] as String? ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/product-details', arguments: scan);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Product thumbnail with premium skeuomorphic frame
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: FoodInsightColors.lightGray.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: imageUrl.isNotEmpty
                      ? Hero(
                          tag: 'scan_${scan['id'] ?? index}',
                          child: CustomImageWidget(
                            imageUrl: imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.fastfood_rounded,
                            size: 22,
                            color: FoodInsightColors.midGray.withValues(alpha: 0.4),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Product name + brand/time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: FoodInsightTypography.body(
                        size: 15,
                        weight: FontWeight.w800,
                        color: FoodInsightColors.deepCharcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (brand.isNotEmpty) ...[
                          Text(
                            brand,
                            style: FoodInsightTypography.caption(
                              size: 12,
                              weight: FontWeight.w600,
                              color: FoodInsightColors.midGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        ],
                        Text(
                          _getTimeAgo(scan['scannedAt']),
                          style: FoodInsightTypography.caption(
                            size: 11,
                            weight: FontWeight.w500,
                            color: FoodInsightColors.midGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Safety badge
              _buildSafetyBadge(safetyStatus),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
          duration: 300.ms,
          delay: (index * 60).ms,
        );
  }

  Widget _buildSafetyBadge(String status) {
    final color = _getSafetyColor(status);
    final text = _getSafetyText(status);
    final icon = _getSafetyIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: FoodInsightRadius.pillAll,
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: FoodInsightTypography.caption(
              size: 11,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSafetyIcon(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'danger':
        return Icons.error_rounded;
      default:
        return Icons.help_outline_rounded;
    }
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

  String _getTimeAgo(dynamic scannedAt) {
    if (scannedAt == null) return 'Recently';
    DateTime? date;
    if (scannedAt is DateTime) {
      date = scannedAt;
    } else if (scannedAt is String) {
      date = DateTime.tryParse(scannedAt);
    }
    if (date == null) return 'Recently';

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: SkeuCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: FoodInsightColors.lightGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: FoodInsightColors.midGray,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No product scans yet',
              style: FoodInsightTypography.heading(
                size: 15,
                weight: FontWeight.w800,
                color: FoodInsightColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan package barcodes to reveal full ingredient insight',
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
