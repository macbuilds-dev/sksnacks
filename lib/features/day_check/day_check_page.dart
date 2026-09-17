import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class DayCheckPage extends ConsumerWidget {
  const DayCheckPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dayCheckRepoProvider);
    final inv = ref.watch(inventoryRepoProvider);

    return Scaffold(
      appBar: kitschAppBar(context, title: Copy.dayTitle),
      body: KitschBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _add(context, ref, 'in'),
                      child: const Text(Copy.dayIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _add(context, ref, 'out'),
                      child: const Text(Copy.dayOut),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<DayCheck>>(
                stream: repo.watchChecks(),
                builder: (context, snap) {
                  final checks = snap.data ?? <DayCheck>[];
                  if (checks.isEmpty) {
                    return const Center(
                      child: Text('Aaj abhi check nahi hua. Shuru karo!'),
                    );
                  }
                  return StreamBuilder<List<Location>>(
                    stream: inv.watchLocations(),
                    builder: (context, locSnap) {
                      final locs = {
                        for (final l in locSnap.data ?? <Location>[])
                          l.id: l.name,
                      };
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: checks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = checks[i];
                          return KitschSticker(
                            child: StickerRow(
                              title:
                                  '${c.kind == 'in' ? Copy.dayIn : Copy.dayOut}'
                                  ' · ${locs[c.locationId] ?? c.locationId}',
                              subtitle: c.note ??
                                  c.at.toString().substring(0, 16),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String kind) async {
    final locs = await ref.read(inventoryRepoProvider).watchLocations().first;
    if (!context.mounted) return;
    if (locs.isEmpty) {
      showNeed(context, Copy.needLocation);
      return;
    }
    var locId = locs.first.id;
    final note = TextEditingController();
    final cash = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(kind == 'in' ? Copy.dayIn : Copy.dayOut),
          content: dialogForm([
            DropdownButtonFormField<String>(
              key: ValueKey(locId),
              initialValue: locId,
              items: locs
                  .map(
                    (l) => DropdownMenuItem(value: l.id, child: Text(l.name)),
                  )
                  .toList(),
              onChanged: (v) => setLocal(() => locId = v!),
              decoration: const InputDecoration(labelText: Copy.location),
            ),
            TextField(
              controller: cash,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: Copy.cashCount),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: Copy.note),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(Copy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(Copy.save),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref.read(dayCheckRepoProvider).add(
            locationId: locId,
            kind: kind,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            cashCount: double.tryParse(cash.text),
          );
    }
  }
}
