import 'package:flutter/material.dart';

/// A proposal never changes targets until Apply Goals succeeds.
class MacroGoalsDialog extends StatefulWidget {
  final Map<String, dynamic> proposal;
  final Future<void> Function() onApply;
  const MacroGoalsDialog(
      {super.key, required this.proposal, required this.onApply});
  @override
  State<MacroGoalsDialog> createState() => _MacroGoalsDialogState();
}

class _MacroGoalsDialogState extends State<MacroGoalsDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _apply() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onApply();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Goals could not be saved. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
          scrollable: true,
          title: const Text('Review proposed goals'),
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.proposal['explanation'] as String? ??
                'Review these general wellness targets.'),
            const SizedBox(height: 16),
            for (final key in ['calories', 'protein', 'carbs', 'fat'])
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                      '${key[0].toUpperCase()}${key.substring(1)}: ${widget.proposal[key]} ${key == 'calories' ? 'kcal' : 'g'}')),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _apply,
                child: Text(_saving ? 'Saving…' : 'Apply Goals')),
          ]));
}
