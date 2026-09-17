import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class CustomerEyeviewPage extends ConsumerStatefulWidget {
  const CustomerEyeviewPage({super.key});

  @override
  ConsumerState<CustomerEyeviewPage> createState() =>
      _CustomerEyeviewPageState();
}

class _CustomerEyeviewPageState extends ConsumerState<CustomerEyeviewPage> {
  String? _partyId;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(khataRepoProvider);

    return Scaffold(
      appBar: kitschAppBar(context, title: Copy.customerTitle),
      body: KitschBackdrop(
        child: StreamBuilder<List<Party>>(
          stream: repo.watchParties(),
          builder: (context, snap) {
            final parties = (snap.data ?? [])
                .where((p) => p.role == 'customer')
                .toList();
            if (parties.isEmpty) {
              return const Center(
                child: Text('Customer party jodo, phir unki nazar dekho.'),
              );
            }
            _partyId ??= parties.first.id;
            final party = parties.firstWhere(
              (p) => p.id == _partyId,
              orElse: () => parties.first,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(Copy.customerHint),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(party.id),
                  initialValue: party.id,
                  decoration: const InputDecoration(labelText: Copy.party),
                  items: parties
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _partyId = v),
                ),
                const SizedBox(height: 16),
                KitschSticker(
                  color: Theme.of(context).colorScheme.tertiary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (party.phone != null) Text(party.phone!),
                      const SizedBox(height: 8),
                      Text(
                        'Baqaya: Rs ${party.balance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unke bills',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StreamBuilder<List<Bill>>(
                  stream: repo.watchBills(),
                  builder: (context, bSnap) {
                    final bills = (bSnap.data ?? [])
                        .where((b) => b.partyId == party.id)
                        .toList();
                    if (bills.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Is party ka koi bill nahi'),
                      );
                    }
                    return Column(
                      children: bills
                          .map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: KitschSticker(
                                shadowDx: 2,
                                shadowDy: 2,
                                borderWidth: 2.5,
                                child: StickerRow(
                                  title:
                                      'Rs ${b.total.toStringAsFixed(0)}',
                                  subtitle: '${b.status} · ${b.kind}',
                                  trailing: Text(
                                    b.createdAt.toString().substring(0, 10),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
