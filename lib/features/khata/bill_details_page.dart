import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../features/invoices/receipt_service.dart';
import '../../l10n/app_copy.dart';

class BillDetailsPage extends ConsumerWidget {
  const BillDetailsPage({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(khataRepoProvider);

    return FutureBuilder<Bill?>(
      future: repo.billById(billId),
      builder: (context, snap) {
        final bill = snap.data;
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.khataBillDetails),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (bill == null) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.khataBillDetails),
            body: const Center(child: Text('Bill nahi mila')),
          );
        }

        return Scaffold(
          appBar: kitschAppBar(
            context,
            title: bill.billNo ?? 'Bill',
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => openBillReceipt(context, ref, bill),
              ),
              IconButton(
                icon: const KitschQrIcon(),
                onPressed: () => showEntityQr(
                  context,
                  title: Copy.qrOfBill,
                  qrCode: bill.qrCode,
                  detailLines: [
                    bill.billNo ?? bill.id,
                    billStatusLabel(bill.status),
                  ],
                ),
              ),
            ],
          ),
          body: KitschBackdrop(
            child: FutureBuilder(
              future: Future.wait([
                repo.partyById(bill.partyId),
                repo.linesFor(bill.id),
              ]),
              builder: (context, dataSnap) {
                if (!dataSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final party = dataSnap.data![0] as Party?;
                final lines = dataSnap.data![1] as List<BillLine>;
                final due = bill.total - bill.paid;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    KitschSticker(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${bill.kind.toUpperCase()} · Rs ${bill.total.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text('${Copy.qrCode}: ${bill.qrCode}'),
                          Text('Status: ${billStatusLabel(bill.status)}'),
                          Text(
                            Copy.billStatusHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text('Party: ${party?.name ?? bill.partyId}'),
                          Text(
                            'By owner: ${ownerDisplayName(bill.createdByOwnerId)}',
                          ),
                          Text('Paid: Rs ${bill.paid.toStringAsFixed(0)}'),
                          Text('Baqi: Rs ${due.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Lines',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KitschSticker(
                          shadowDx: 2,
                          shadowDy: 2,
                          borderWidth: 2.5,
                          child: StickerRow(
                            title: l.description,
                            subtitle:
                                '${l.qty} × ${l.unitPrice.toStringAsFixed(0)}',
                            trailing: Text(
                              'Rs ${l.lineTotal.toStringAsFixed(0)}',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (bill.status != 'void' && bill.status != 'paid')
                      FilledButton.icon(
                        onPressed: () => _payAgainst(context, ref, bill),
                        icon: const Icon(Icons.payments),
                        label: const Text(Copy.khataPay),
                      ),
                    if (bill.status != 'void') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(khataRepoProvider).voidBill(bill.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Void bill'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _payAgainst(
    BuildContext context,
    WidgetRef ref,
    Bill bill,
  ) async {
    final amount = TextEditingController(
      text: (bill.total - bill.paid).toStringAsFixed(0),
    );
    var method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.khataPay),
          content: dialogForm([
            DropdownButtonFormField<String>(
              key: ValueKey(method),
              initialValue: method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text(Copy.payCash)),
                DropdownMenuItem(
                  value: 'online',
                  child: Text(Copy.payOnline),
                ),
              ],
              onChanged: (v) => setLocal(() => method = v!),
              decoration: const InputDecoration(labelText: Copy.billPayMethod),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: Copy.amount),
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
    if (ok != true) return;
    final owner = ref.read(authControllerProvider);
    final amt = double.tryParse(amount.text) ?? 0;
    if (amt <= 0) {
      if (context.mounted) showNeed(context, 'Amount likho');
      return;
    }
    try {
      await ref.read(khataRepoProvider).recordPayment(
            partyId: bill.partyId,
            amount: amt,
            billId: bill.id,
            method: method,
            createdByOwnerId: owner?.ownerId,
          );
      if (!context.mounted) return;
      showOk(context, Copy.paymentSaved);
      final updated = await ref.read(khataRepoProvider).billById(bill.id);
      if (updated != null && context.mounted) {
        await openBillReceipt(context, ref, updated);
      }
    } catch (e) {
      if (context.mounted) showFail(context, '$e');
    }
  }
}
