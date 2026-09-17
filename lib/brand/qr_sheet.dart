import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_copy.dart';
import 'kitsch_widgets.dart';
import 'ui_helpers.dart';

/// Shows a printable kitsch QR sheet. Payload is the stable qrCode;
/// app loads fresh details from DB on scan.
Future<void> showEntityQr(
  BuildContext context, {
  required String title,
  required String qrCode,
  List<String> detailLines = const [],
  bool qrOnly = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: dialogForm([
          Center(
            child: KitschSticker(
              color: scheme.surface,
              child: QrImageView(
                data: qrCode,
                size: 200,
                backgroundColor: scheme.surface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SelectableText(
              qrCode,
              style: Theme.of(ctx).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (!qrOnly && detailLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              Copy.qrFreshHint,
              style: Theme.of(ctx).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            for (final line in detailLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: Theme.of(ctx).textTheme.bodyMedium),
              ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: qrCode));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showNeed(context, Copy.qrCopied);
              }
            },
            child: const Text(Copy.copyQr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Copy.done),
          ),
        ],
      );
    },
  );
}
