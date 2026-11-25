import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_design_system.dart';

class ActionBarWidget extends StatelessWidget {
  final Map<String, dynamic> productData;
  final VoidCallback? onAddToDietLog;
  final VoidCallback? onAddToShoppingList;

  const ActionBarWidget({
    super.key,
    required this.productData,
    this.onAddToDietLog,
    this.onAddToShoppingList,
  });

  @override
  Widget build(BuildContext context) {
    final barcode = productData['barcode']?.toString() ?? '';
    final hasOffBarcode = RegExp(r'^\d{8,14}$').hasMatch(barcode);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Copy product link',
              icon: const Icon(Icons.link_rounded),
              onPressed: !hasOffBarcode
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(
                        text: 'https://world.openfoodfacts.org/product/$barcode',
                      ));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Product link copied')),
                        );
                      }
                    },
            ),
            if (onAddToShoppingList != null) ...[
              const SizedBox(width: 4),
              IconButton.outlined(
                tooltip: 'Add to shopping list',
                onPressed: onAddToShoppingList,
                style: IconButton.styleFrom(
                  foregroundColor: FoodInsightColors.scannerGreenDark,
                  side: BorderSide(
                    color: FoodInsightColors.scannerGreen.withValues(alpha: 0.45),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddToDietLog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add to diet log'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: FoodInsightColors.scannerGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
