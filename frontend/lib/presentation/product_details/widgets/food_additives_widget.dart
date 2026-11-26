import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/analytics_service.dart';
import '../../../services/app_governance_service.dart';
import '../../../services/food_additive_service.dart';

class FoodAdditivesWidget extends StatelessWidget {
  final Map<String, dynamic> product;
  const FoodAdditivesWidget({super.key, required this.product});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppGovernanceService.instance,
        builder: (context, _) => FutureBuilder<FoodAdditiveService>(
          future: FoodAdditiveService.load(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final rows = AppGovernanceService.applyAdditiveOverrides(
              product: product,
              baseRows: snapshot.data!.inspect(product),
              overrides: AppGovernanceService.instance.additiveOverrides,
            );
            if (rows.isEmpty) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food additives',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Based on available ingredient data. An INS number identifies an additive; presence alone is not a health-risk verdict.'),
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('INS ${row['ins']} · ${row['name']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                                if (row['safetyTier'] != null &&
                                    row['safetyTier'].toString().isNotEmpty)
                                  Chip(
                                    label: Text(row['safetyTier']
                                        .toString()
                                        .toUpperCase()),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (row['functionalClasses'] is List)
                              Text((row['functionalClasses'] as List)
                                  .join(' · ')),
                            if (row['summary'] != null &&
                                row['summary'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(row['summary'].toString()),
                              ),
                            if (row['dietaryNotes'] != null &&
                                row['dietaryNotes'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  row['dietaryNotes'].toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            for (final source in row['sources'] as List? ?? [])
                              TextButton(
                                onPressed: () async {
                                  AnalyticsService.record(
                                      UsageEvent.additiveSourceViewed);
                                  await launchUrl(
                                    Uri.parse(source['reference'] as String),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: Text('Source: ${source['authority']}'),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                        'The glossary is limited. Unknown codes do not mean safe or unsafe.'),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
