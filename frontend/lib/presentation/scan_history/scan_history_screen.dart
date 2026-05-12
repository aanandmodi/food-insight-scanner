import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/product_service.dart';
import '../../services/firestore_service.dart';

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

    // Prefer cloud delete if we have a Firestore doc id.
    if (scanId != null && scanId.isNotEmpty) {
      try {
        await _firestore.deleteScan(scanId);
      } catch (e) {
        debugPrint('Error deleting scan from Firestore: $e');
      }
    } else if (barcode.isNotEmpty) {
      // Offline/guest mode: delete from local SQLite so it doesn't reappear.
      await _productService.deleteLocalScan(barcode);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan removed from history')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Scan History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestore.scanHistoryStream(limit: 50),
        builder: (context, snapshot) {
          // If Firebase isn't ready (guest/offline), the stream is empty.
          // Fall back to local SQLite history (still dynamic via refresh).
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (snapshot.hasData && (snapshot.data?.isNotEmpty ?? false)) {
            final scans = snapshot.data!;
            return ListView.separated(
              padding: EdgeInsets.all(4.w),
              itemCount: scans.length,
              separatorBuilder: (context, index) => SizedBox(height: 2.h),
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

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _productService.getScanHistory(),
            builder: (context, localSnapshot) {
              if (localSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                );
              }

              final localScans = localSnapshot.data ?? [];
              if (localScans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 15.w,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'No scans yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'Scan a product barcode to see it here',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: colorScheme.primary,
                child: ListView.separated(
                  padding: EdgeInsets.all(4.w),
                  itemCount: localScans.length,
                  separatorBuilder: (context, index) => SizedBox(height: 2.h),
                  itemBuilder: (context, index) {
                    final scan = localScans[index];
                    return _buildHistoryItem(context, scan)
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: Duration(
                              milliseconds: (index * 50).clamp(0, 300)),
                        )
                        .slideY(begin: 0.03, end: 0);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, Map<String, dynamic> scan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(scan['id']?.toString() ??
          scan['barcode']?.toString() ??
          UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 4.w),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteScan(scan),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(
            context,
            '/product-details',
            arguments: scan,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: isDark
                  ? AppTheme.glassmorphicDecoration(borderRadius: 16)
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              padding: EdgeInsets.all(3.w),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: scan['image'] != null &&
                            scan['image'].toString().isNotEmpty
                        ? Image.network(
                            scan['image'],
                            width: 15.w,
                            height: 15.w,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 15.w,
                              height: 15.w,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[200],
                              child: const Icon(Icons.image_not_supported,
                                  size: 20),
                            ),
                          )
                        : Container(
                            width: 15.w,
                            height: 15.w,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[200],
                            child: const Icon(Icons.fastfood, size: 20),
                          ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scan['name'] ?? 'Unknown Product',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          scan['brand'] ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          _formatDate(scan['scannedAt']),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return '';
    }
  }
}
