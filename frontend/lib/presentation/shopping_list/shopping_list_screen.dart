// lib/presentation/shopping_list/shopping_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../theme/app_design_system.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _localDb.getShoppingList();
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (e) {
      debugPrint('Error loading shopping list: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleItem(String id, bool checked) async {
    HapticFeedback.lightImpact();
    try {
      await _localDb.toggleShoppingItem(id, checked);
      try {
        await FirestoreService().toggleShoppingItem(id, checked);
      } catch (_) {}
      await _loadItems();
    } catch (e) {
      debugPrint('Error toggling item: $e');
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _localDb.deleteShoppingItem(id);
      try {
        await FirestoreService().deleteShoppingItem(id);
      } catch (_) {}
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item removed'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  Future<void> _clearChecked(List<Map<String, dynamic>> items) async {
    final checkedCount = items.where((i) => i['checked'] == true).length;
    if (checkedCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Clear Checked Items', style: FoodInsightTypography.heading(size: 20, weight: FontWeight.w800, color: FoodInsightColors.deepCharcoal)),
        content: Text('Remove $checkedCount checked item(s)?', style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: FoodInsightColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
            ),
            child: Text('Clear', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _localDb.clearCheckedShoppingItems();
        try {
          await FirestoreService().clearCheckedShoppingItems();
        } catch (_) {}
        await _loadItems();
      } catch (e) {
        debugPrint('Error clearing checked items: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _items.where((i) => i['checked'] != true).toList();
    final checkedItems = _items.where((i) => i['checked'] == true).toList();

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Shopping List',
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
        actions: [
          if (checkedItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: FoodInsightColors.scannerGreen),
              onPressed: () => _clearChecked(_items),
              tooltip: 'Clear checked items',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
              )
            : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    color: FoodInsightColors.scannerGreen,
                    backgroundColor: Colors.white,
                    child: ListView(
                      padding: EdgeInsets.all(5.w),
                      children: [
                        if (pendingItems.isNotEmpty) ...[
                          Text(
                            'To Buy (${pendingItems.length})',
                            style: FoodInsightTypography.heading(
                              size: 16,
                              weight: FontWeight.w800,
                              color: FoodInsightColors.deepCharcoal,
                            ),
                          ).animate().fadeIn(),
                          SizedBox(height: 1.5.h),
                          ...pendingItems.map((item) => _buildListItem(item)),
                        ],
                        if (checkedItems.isNotEmpty) ...[
                          if (pendingItems.isNotEmpty) SizedBox(height: 3.h),
                          Text(
                            'Checked (${checkedItems.length})',
                            style: FoodInsightTypography.heading(
                              size: 16,
                              weight: FontWeight.w800,
                              color: FoodInsightColors.midGray,
                            ),
                          ).animate().fadeIn(),
                          SizedBox(height: 1.5.h),
                          ...checkedItems.map((item) => _buildListItem(item)),
                        ],
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
      ),
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
              Icons.shopping_basket_rounded,
              size: 15.w,
              color: FoodInsightColors.scannerGreen,
            ),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          SizedBox(height: 3.h),
          Text(
            'Your list is empty',
            style: FoodInsightTypography.heading(
              size: 20,
              weight: FontWeight.w800,
              color: FoodInsightColors.deepCharcoal,
            ),
          ).animate().fadeIn(delay: 400.ms),
          SizedBox(height: 1.h),
          Text(
            'Save healthy products from\nthe scanner to buy them later.',
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

  Widget _buildListItem(Map<String, dynamic> item) {
    final bool checked = item['checked'] == true;
    final String id = item['id'];
    final String name = item['name'] ?? 'Unknown Product';
    final String brand = item['brand'] ?? 'Unknown Brand';
    final String score = item['score'] ?? '0';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: FoodInsightColors.healthRed,
          borderRadius: FoodInsightRadius.mdAll,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteItem(id),
      child: GestureDetector(
        onTap: () => _toggleItem(id, !checked),
        child: Container(
          margin: EdgeInsets.only(bottom: 1.5.h),
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: FoodInsightRadius.mdAll,
            boxShadow: FoodInsightShadows.subtleCard,
            border: Border.all(
              color: checked ? FoodInsightColors.scannerGreenLight : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? FoodInsightColors.scannerGreen : Colors.transparent,
                  border: Border.all(
                    color: checked ? FoodInsightColors.scannerGreen : FoodInsightColors.outlineGray,
                    width: 2,
                  ),
                ),
                child: checked
                    ? Icon(Icons.check, size: 4.w, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 3.w),
              
              // Thumbnail
              if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: FoodInsightRadius.smAll,
                  child: Image.network(
                    item['imageUrl'],
                    width: 12.w,
                    height: 12.w,
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
                        color: checked ? FoodInsightColors.midGray : FoodInsightColors.deepCharcoal,
                      ).copyWith(
                        decoration: checked ? TextDecoration.lineThrough : null,
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
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score).withValues(alpha: 0.1),
                    borderRadius: FoodInsightRadius.smAll,
                  ),
                  child: Text(
                    score.toUpperCase(),
                    style: FoodInsightTypography.caption(
                      size: 14,
                      weight: FontWeight.w800,
                      color: _getScoreColor(score),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        color: FoodInsightColors.warmWhite,
        borderRadius: FoodInsightRadius.smAll,
      ),
      child: Icon(Icons.fastfood_rounded, color: FoodInsightColors.midGray, size: 6.w),
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
