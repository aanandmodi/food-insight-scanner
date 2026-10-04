import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/food_additive_service.dart';
import '../../../services/analytics_service.dart';

class FoodAdditivesWidget extends StatelessWidget {
  final Map<String, dynamic> product;
  const FoodAdditivesWidget({super.key, required this.product});
  @override
  Widget build(BuildContext context) => FutureBuilder<FoodAdditiveService>(
      future: FoodAdditiveService.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final rows = snapshot.data!.inspect(product);
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
                                  Text('INS ${row['ins']} · ${row['name']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  if (row['functionalClasses'] is List)
                                    Text((row['functionalClasses'] as List)
                                        .join(' · ')),
                                  for (final source
                                      in row['sources'] as List? ?? [])
                                    TextButton(
                                        onPressed: () async {
                                          AnalyticsService.record(
                                              UsageEvent.additiveSourceViewed);
                                          await launchUrl(
                                              Uri.parse(source['reference']
                                                  as String),
                                              mode: LaunchMode
                                                  .externalApplication);
                                        },
                                        child: Text(
                                            'Source: ${source['authority']}')),
                                ])),
                      const SizedBox(height: 8),
                      const Text(
                          'The glossary is limited. Unknown codes do not mean safe or unsafe.'),
                    ])));
      });
}
