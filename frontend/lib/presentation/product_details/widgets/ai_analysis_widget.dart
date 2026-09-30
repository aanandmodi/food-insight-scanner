import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

class AiAnalysisWidget extends StatelessWidget {
  final Map<String, dynamic>? aiAnalysis;
  const AiAnalysisWidget({super.key, required this.aiAnalysis});
  @override
  Widget build(BuildContext context) {
    final summary = aiAnalysis?['summary'];
    if (summary is! String || summary.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: FoodInsightRadius.mdAll,
        border: Border.all(color: FoodInsightColors.outlineGray)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI explanation', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(summary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
        const SizedBox(height: 12),
        Text('AI can make mistakes. Check the product facts and package label.', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
