import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_design_system.dart';

class ActionBarWidget extends StatelessWidget {
  final Map<String, dynamic> productData;
  final VoidCallback? onAddToDietLog;
  const ActionBarWidget({super.key, required this.productData, this.onAddToDietLog});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: SafeArea(top: false, child: Row(children: [
      IconButton(tooltip: 'Copy product link', icon: const Icon(Icons.link_rounded),
        onPressed: () async {
          final barcode = productData['barcode']?.toString() ?? '';
          if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) return;
          await Clipboard.setData(ClipboardData(text: 'https://world.openfoodfacts.org/product/$barcode'));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product link copied')));
        }),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton.icon(onPressed: onAddToDietLog,
        icon: const Icon(Icons.add_rounded), label: const Text('Add to diet log'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48),
          backgroundColor: FoodInsightColors.scannerGreen, foregroundColor: Colors.white))),
    ])),
  );
}
