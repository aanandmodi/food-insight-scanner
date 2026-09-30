import 'package:flutter/material.dart';

Future<bool> confirmAccountDeletion(BuildContext context) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Delete Account'),
              content: const Text(
                  'This permanently deletes your account, profile, meals, scans and activity records. You may be asked to sign in again. This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            )) ??
    false;
