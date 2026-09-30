import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/providers/activity_provider.dart';

Future<void> showHealthConnectionPrompt(BuildContext context) async {
  final provider = context.read<ActivityProvider>();
  final choice = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
    scrollable: true,
    title: const Text('Connect activity data'),
    content: const Text('Food Insight can read steps and active calories from Health Connect to show your daily activity. Daily totals are saved to your account. Distance is estimated.\n\nYou can use the phone step counter instead; its calories and distance are estimates. Scanning food works without either connection.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Not now')),
      if (provider.source != ActivityDataSource.none)
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'disconnect'), child: const Text('Disconnect activity')),
      TextButton(onPressed: () => Navigator.pop(dialogContext, 'steps'), child: const Text('Use step counter')),
      FilledButton(onPressed: () => Navigator.pop(dialogContext, 'health'), child: const Text('Connect Health')),
    ],
  ));
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'disconnect') {
      await provider.disconnect();
    } else if (choice == 'health') {
      await provider.refresh(requestPermission: true);
    } else {
      await provider.connectPedometer();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(choice == 'disconnect' ? 'Activity disconnected. Saved daily totals remain in your account.' : provider.source == ActivityDataSource.none ? 'No activity data is available yet.' : 'Activity connection updated.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is StateError ? error.message.toString() : 'Activity data is unavailable. You can try again from Settings.')));
    }
  }
}
