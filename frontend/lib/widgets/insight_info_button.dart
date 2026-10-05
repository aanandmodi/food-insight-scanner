import 'package:flutter/material.dart';

/// Keeps the dashboard focused while making data limitations easy to inspect.
class InsightInfoButton extends StatelessWidget {
  final String title;
  final String information;
  const InsightInfoButton(
      {super.key, required this.title, required this.information});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'About $title',
        iconSize: 19,
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(information,
                      style: Theme.of(context).textTheme.bodyLarge),
                ]),
          ),
        ),
      );
}
