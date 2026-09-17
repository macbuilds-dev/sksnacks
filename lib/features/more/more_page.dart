import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/kitsch_qr_fab.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../core/license/feature_gate.dart';
import '../../features/auth/auth_providers.dart';
import '../../l10n/app_copy.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <(String, Widget, String, String?)>[
      (Copy.cashTitle, const Icon(Icons.payments), '/cash', 'dayCash'),
      (Copy.dayTitle, const Icon(Icons.today), '/day-check', 'dayCash'),
      (Copy.invoiceTitle, const Icon(Icons.share), '/invoices', 'invoices'),
      (Copy.qrTitle, const KitschQrIcon(size: 26), '/qr', 'qr'),
      (Copy.customerTitle, const Icon(Icons.visibility), '/customer', 'customerEyeview'),
      (Copy.settingsTitle, const Icon(Icons.settings), '/settings', null),
    ];

    return KitschBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              Copy.navMore,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Cash, QR, settings — sab yahan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...tiles.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KitschSticker(
                  onTap: () async {
                    final feature = t.$4;
                    if (feature == null) {
                      context.push(t.$3);
                      return;
                    }
                    await pushIfFeature(context, ref, t.$3, feature);
                  },
                  child: StickerRow(
                    leading: t.$2,
                    title: t.$1,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: 'Sign out?',
                  message: 'Google session band ho jayegi is device pe.',
                  confirmLabel: Copy.signOut,
                  destructive: true,
                );
                if (ok && context.mounted) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
              child: const Text(Copy.signOut),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Powered by Baithak',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
