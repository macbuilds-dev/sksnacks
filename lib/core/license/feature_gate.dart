import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'license_providers.dart';

/// After pilot month, locked modules show a dialog (cart UI comes with Baithak admin).
Future<bool> ensureFeatureOrPrompt(
  BuildContext context,
  WidgetRef ref,
  String featureKey, {
  String? title,
  String? message,
}) async {
  final snap = await ref.read(licenseSnapshotProvider.future);
  if (snap.isEnabled(featureKey)) return true;
  if (!context.mounted) return false;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? 'Feature locked'),
      content: Text(
        message ??
            'Is module ka trial/paid time khatam. Renew karein, discontinue, '
            'ya read-only rehne dein. Cart / Baithak admin se unlock hoga.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'dismiss'),
          child: const Text('Continue without'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'settings'),
          child: const Text('Open settings'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'ok'),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  if (!context.mounted) return false;
  if (choice == 'settings') {
    context.push('/settings');
  }
  // Locked: do not open the feature route.
  return false;
}

Future<void> pushIfFeature(
  BuildContext context,
  WidgetRef ref,
  String route,
  String featureKey,
) async {
  final ok = await ensureFeatureOrPrompt(context, ref, featureKey);
  if (ok && context.mounted) context.push(route);
}
