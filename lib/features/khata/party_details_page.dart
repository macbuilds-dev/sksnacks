import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/entity_photo.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class PartyDetailsPage extends ConsumerWidget {
  const PartyDetailsPage({super.key, required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(khataRepoProvider);

    return FutureBuilder<Party?>(
      future: repo.partyById(partyId),
      builder: (context, snap) {
        final p = snap.data;
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.khataPartyDetails),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (p == null) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.khataPartyDetails),
            body: const Center(child: Text('Party nahi mili')),
          );
        }

        return Scaffold(
          appBar: kitschAppBar(
            context,
            title: p.name,
            actions: [
              IconButton(
                icon: const KitschQrIcon(),
                onPressed: () => showEntityQr(
                  context,
                  title: Copy.qrOfParty,
                  qrCode: p.qrCode,
                  detailLines: [p.name, p.role],
                ),
              ),
            ],
          ),
          body: KitschBackdrop(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KitschSticker(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: EntityPhotoThumb(
                          path: p.imagePath,
                          size: 120,
                          radius: 18,
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(p.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('${Copy.role}: ${p.role}'),
                      Text('${Copy.qrCode}: ${p.qrCode}'),
                      if (p.phone != null) Text('${Copy.phone}: ${p.phone}'),
                      if (p.city != null) Text('${Copy.city}: ${p.city}'),
                      if (p.address != null)
                        Text('${Copy.address}: ${p.address}'),
                      const SizedBox(height: 8),
                      Text(
                        'Baqaya: Rs ${p.balance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Is party ke bills',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<List<Bill>>(
                  stream: repo.watchBills(),
                  builder: (context, billSnap) {
                    final bills = (billSnap.data ?? [])
                        .where((b) => b.partyId == p.id)
                        .toList();
                    if (bills.isEmpty) {
                      return const Text('Abhi koi bill nahi');
                    }
                    return Column(
                      children: [
                        for (final b in bills)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: KitschSticker(
                              onTap: () =>
                                  context.push('/udhaar/bill/${b.id}'),
                              child: StickerRow(
                                title:
                                    '${b.billNo ?? 'Bill'} · Rs ${b.total.toStringAsFixed(0)}',
                                subtitle:
                                    '${b.kind} · ${b.status} · paid ${b.paid.toStringAsFixed(0)}',
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

