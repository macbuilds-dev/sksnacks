import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../features/invoices/receipt_service.dart';
import '../../l10n/app_copy.dart';

class CashPage extends ConsumerWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(cashRepoProvider);

    return Scaffold(
      appBar: kitschAppBar(context, title: Copy.cashTitle),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        label: const Text(Copy.cashEntryFab),
        icon: const Icon(Icons.add),
      ),
      body: KitschBackdrop(
        child: StreamBuilder<List<CashEntry>>(
          stream: repo.watchEntries(),
          builder: (context, snap) {
            final rows = snap.data ?? [];
            final net = rows.fold<double>(
              0,
              (sum, e) => sum + (e.kind == 'in' ? e.amount : -e.amount),
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: KitschSticker(
                    color: Theme.of(context).colorScheme.tertiary,
                    child: Text(
                      '${Copy.cashOnHand}: Rs ${net.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text(Copy.cashEmpty))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = rows[i];
                            final inMoney = e.kind == 'in';
                            return KitschSticker(
                              color: inMoney
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary,
                              child: StickerRow(
                                title:
                                    '${inMoney ? Copy.cashIn : Copy.cashOut} · ${e.source}',
                                subtitle: e.note ??
                                    e.at.toString().substring(0, 16),
                                trailing: Text(
                                  '${inMoney ? '+' : '-'}Rs ${e.amount.toStringAsFixed(0)}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    var kind = 'in';
    final amount = TextEditingController();
    final note = TextEditingController();
    final category = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.cashEntry),
          content: dialogForm([
            DropdownButtonFormField<String>(
              key: ValueKey(kind),
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'in', child: Text(Copy.cashIn)),
                DropdownMenuItem(value: 'out', child: Text(Copy.cashOut)),
              ],
              onChanged: (v) => setLocal(() => kind = v!),
              decoration: const InputDecoration(labelText: Copy.cashKind),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: Copy.amount),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: Copy.cashCategory),
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
    if (ok == true && context.mounted) {
      final owner = ref.read(authControllerProvider);
      final amt = double.tryParse(amount.text) ?? 0;
      if (amt <= 0) {
        showNeed(context, 'Amount likho');
        return;
      }
      final id = await ref.read(cashRepoProvider).add(
            kind: kind,
            amount: amt,
            category:
                category.text.trim().isEmpty ? null : category.text.trim(),
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            actorOwnerId: owner?.ownerId,
          );
      if (!context.mounted) return;
      showOk(context, Copy.cashSaved);
      await openReceiptPreview(
        context,
        ReceiptDraft(
          id: id,
          headline: 'CASH RECEIPT',
          ownerName: owner?.displayName,
          at: DateTime.now(),
          mood: moodForCashKind(kind),
          meta: [
            ('Type', kind == 'in' ? Copy.cashIn : Copy.cashOut),
            ('Amount', 'Rs ${amt.toStringAsFixed(0)}'),
            if (category.text.trim().isNotEmpty)
              ('Category', category.text.trim()),
            if (note.text.trim().isNotEmpty) ('Note', note.text.trim()),
          ],
        ),
        syncCollection: 'cash_entries',
      );
    }
  }
}
