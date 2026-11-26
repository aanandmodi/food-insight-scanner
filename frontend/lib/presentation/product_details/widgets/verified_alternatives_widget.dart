import 'package:flutter/material.dart';
import '../../../services/cloud_function_service.dart';
import '../../../services/analytics_service.dart';

class VerifiedAlternativesWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> profile;
  const VerifiedAlternativesWidget(
      {super.key, required this.product, required this.profile});
  @override
  State<VerifiedAlternativesWidget> createState() =>
      _VerifiedAlternativesWidgetState();
}

class _VerifiedAlternativesWidgetState
    extends State<VerifiedAlternativesWidget> {
  bool _loading = false;
  List<Map<String, dynamic>>? _rows;
  String? _error;
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await CloudFunctionService().getAlternatives(
          productData: widget.product, userProfile: widget.profile);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      debugPrint('Verified alternatives error (${e.runtimeType}): $e');
      if (mounted) {
        setState(() => _error = e is AiRequestException
            ? e.message
            : 'Could not load verified alternatives. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verified alternatives',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Open Food Facts records listed for India. Check the current label; availability and prices are not verified.'),
        if (_rows == null || _error != null)
          OutlinedButton(
              onPressed: _loading ? null : _load,
              child: Text(_loading
                  ? 'Comparing products…'
                  : _error != null
                      ? 'Retry comparisons'
                      : 'Find a better match')),
        if (_error != null) Text(_error!),
        if (_rows?.isEmpty == true)
          const Text('No verified alternative found yet.'),
        for (final row in _rows ?? <Map<String, dynamic>>[])
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['product']['name'] as String,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            'Food Fit ${row['score']}${row['previousScore'] == null ? '' : ' vs ${row['previousScore']}'}'),
                        for (final reason in row['comparisons'] as List)
                          Text(reason as String),
                        TextButton(
                            onPressed: () {
                              AnalyticsService.record(
                                  UsageEvent.alternativeViewed);
                              Navigator.pushNamed(context, '/product-details',
                                  arguments: row['product']);
                            },
                            child: const Text('View product')),
                      ]))),
      ]);
}
