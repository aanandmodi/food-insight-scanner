// lib/presentation/scan_history/scan_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/product_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_design_system.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final FirestoreService _firestore = FirestoreService();
  final ProductService _productService = ProductService();

  Future<void> _deleteScan(Map<String, dynamic> scan) async {
    final scanId = scan['id'] as String?;
    final barcode = (scan['barcode'] as String?) ?? '';

    if (scanId != null && scanId.isNotEmpty) {
      try {
        await _firestore.deleteScan(scanId);
      } catch (e) {
        debugPrint('Error deleting scan from Firestore: $e');
      }
    } else if (barcode.isNotEmpty) {
      await _productService.deleteLocalScan(barcode);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan removed from history'),
          backgroundColor: FoodInsightColors.scannerGreen,
        ),
      );
      // Trigger a rebuild to reflect local deletions if using future builder
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Scan History',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w900,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: FoodInsightColors.deepCharcoal),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestore.scanHistoryStream(limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
              );
            }

            if (snapshot.hasData && (snapshot.data?.isNotEmpty ?? false)) {
              final scans = snapshot.data!;
              return _buildList(scans);
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _productService.getScanHistory(),
              builder: (context, localSnapshot) {
                if (localSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
                  );
                }

                if (localSnapshot.hasData && (localSnapshot.data?.isNotEmpty ?? false)) {
                  return _buildList(localSnapshot.data!);
                }

                return _buildEmptyState();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> scans) {
    return ListView.separated(
      padding: EdgeInsets.all(5.w),
      itemCount: scans.length,
      separatorBuilder: (context, index) => SizedBox(height: 1.5.h),
      itemBuilder: (context, index) {
        final scan = scans[index];
        return _buildHistoryItem(context, scan)
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: (index * 50).clamp(0, 300)),
            )
            .slideY(begin: 0.03, end: 0);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: FoodInsightColors.scannerGreenLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 15.w,
              color: FoodInsightColors.scannerGreen,
            ),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          SizedBox(height: 3.h),
          Text(
            'No scans yet',
            style: FoodInsightTypography.heading(
              size: 20,
              weight: FontWeight.w800,
              color: FoodInsightColors.deepCharcoal,
            ),
          ).animate().fadeIn(delay: 400.ms),
          SizedBox(height: 1.h),
          Text(
            'Your recent product scans\nwill appear here.',
            textAlign: TextAlign.center,
            style: FoodInsightTypography.body(
              size: 15,
              color: FoodInsightColors.midGray,
            ),
          ).animate().fadeIn(delay: 500.ms),
          SizedBox(height: 4.h),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            label: Text('Scan a Product', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.mdAll),
            ),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> scan) {
    final name = scan['name'] ?? 'Unknown Product';
    final brand = scan['brand'] ?? 'Unknown Brand';
    final barcode = scan['barcode'] ?? '';
    final score = scan['score'] ?? '0';
    final imageUrl = scan['imageUrl'];

    return Dismissible(
      key: Key(scan['id']?.toString() ?? barcode),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: FoodInsightColors.healthRed,
          borderRadius: FoodInsightRadius.mdAll,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteScan(scan),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (barcode.isNotEmpty) {
            Navigator.pushNamed(
              context,
              AppRoutes.productDetails,
              arguments: barcode,
            );
          }
        },
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: FoodInsightRadius.mdAll,
            boxShadow: FoodInsightShadows.subtleCard,
          ),
          child: Row(
            children: [
              // Thumbnail
              if (imageUrl != null && imageUrl.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: FoodInsightRadius.smAll,
                  child: Image.network(
                    imageUrl,
                    width: 14.w,
                    height: 14.w,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
                  ),
                )
              else
                _buildPlaceholderIcon(),
              
              SizedBox(width: 3.w),
              
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: FoodInsightTypography.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: FoodInsightColors.deepCharcoal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.2.h),
                    Text(
                      brand,
                      style: FoodInsightTypography.caption(
                        size: 12,
                        color: FoodInsightColors.midGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Nutri-Score
              if (score != '0') ...[
                SizedBox(width: 2.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score).withValues(alpha: 0.1),
                    borderRadius: FoodInsightRadius.smAll,
                  ),
                  child: Text(
                    score.toUpperCase(),
                    style: FoodInsightTypography.caption(
                      size: 15,
                      weight: FontWeight.w800,
                      color: _getScoreColor(score),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 14.w,
      height: 14.w,
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        borderRadius: FoodInsightRadius.smAll,
      ),
      child: Icon(Icons.fastfood_rounded, color: FoodInsightColors.midGray, size: 7.w),
    );
  }

  Color _getScoreColor(String score) {
    switch (score.toLowerCase()) {
      case 'a':
        return FoodInsightColors.healthGreen;
      case 'b':
        return FoodInsightColors.healthLightGreen;
      case 'c':
        return FoodInsightColors.healthYellow;
      case 'd':
        return FoodInsightColors.healthOrange;
      case 'e':
        return FoodInsightColors.healthRed;
      default:
        return FoodInsightColors.midGray;
    }
  }
}
