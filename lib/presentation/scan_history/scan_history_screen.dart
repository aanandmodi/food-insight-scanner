import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/product_service.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scanHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await ProductService().getScanHistory();
      setState(() {
        _scanHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Scan History',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: AppTheme.lightTheme.colorScheme.onSurface,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scanHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 15.w,
                        color: AppTheme.lightTheme.disabledColor,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'No scans yet',
                        style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.lightTheme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: EdgeInsets.all(4.w),
                    itemCount: _scanHistory.length,
                    separatorBuilder: (context, index) => SizedBox(height: 2.h),
                    itemBuilder: (context, index) {
                      final scan = _scanHistory[index];
                      // Use a ListTile or custom card to display the scan
                      return _buildHistoryItem(scan);
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> scan) {
    // A simple list item since we might not have ProductCardCompact isolated yet
    // Or we can construct a nice card here.
    return InkWell(
      onTap: () {
         Navigator.pushNamed(
          context,
          '/product-details',
          arguments: scan,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(3.w),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: scan['image'] != null && scan['image'].toString().isNotEmpty
                  ? Image.network(
                      scan['image'],
                      width: 15.w,
                      height: 15.w,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 15.w,
                        height: 15.w,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 20),
                      ),
                    )
                  : Container(
                      width: 15.w,
                      height: 15.w,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 20),
                    ),
            ),
            SizedBox(width: 4.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan['name'] ?? 'Unknown Product',
                    style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    scan['brand'] ?? '',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  // Date
                  Text(
                   _formatDate(scan['scannedAt']),
                    style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
          ],
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
