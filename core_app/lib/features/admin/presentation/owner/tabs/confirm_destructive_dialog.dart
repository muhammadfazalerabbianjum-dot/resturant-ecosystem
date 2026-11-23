import 'package:flutter/material.dart';
import 'package:labs/l10n/app_localizations.dart';

/// UX-2 (05-P2-UX-CONFIRM): shared confirmation gate before any destructive
/// owner mutation (delete branch / delete menu item) — never mutate silently.
Future<bool?> confirmDestructive(
  BuildContext context,
  String title,
  String body,
) {
  final loc = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(loc.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(loc.delete),
        ),
      ],
    ),
  );
}
