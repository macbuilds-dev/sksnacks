import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';
import '../khata/create_bill_dialog.dart';
import 'receipt_preview_page.dart';

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(khataRepoProvider);

    return Scaffold(
      appBar: kitschAppBar(context, title: Copy.invoiceTitle),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createBillWithInventoryPicker(
          context,
          ref,
          emptyPartiesMessage: Copy.needPartyInvoice,
          dialogTitle: Copy.invoiceCreate,
        ),
        icon: const Icon(Icons.add),
        label: const Text(Copy.invoiceCreate),
      ),
      body: KitschBackdrop(
        child: StreamBuilder<List<Bill>>(
          stream: repo.watchBills(),
          builder: (context, snap) {
            final bills = snap.data ?? [];
            if (bills.isEmpty) {
              return const Center(
                child: Text('Bill banao, WhatsApp pe udhaaro.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = bills[i];
                return KitschSticker(
                  child: StickerRow(
                    title:
                        '${b.billNo ?? 'Bill'} · Rs ${b.total.toStringAsFixed(0)}',
                    subtitle: '${b.qrCode} · ${b.kind} · ${b.status}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const KitschQrIcon(),
                          tooltip: Copy.showQr,
                          onPressed: () => _showBillQr(context, ref, b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.print),
                          tooltip: 'Print receipt',
                          onPressed: () => openBillReceipt(context, ref, b),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showBillQr(
    BuildContext context,
    WidgetRef ref,
    Bill b,
  ) async {
    final party = await ref.read(khataRepoProvider).partyById(b.partyId);
    if (!context.mounted) return;
    await showEntityQr(
      context,
      title: Copy.qrOfBill,
      qrCode: b.qrCode,
      detailLines: [
        b.billNo ?? b.id,
        'Party: ${party?.name ?? b.partyId}',
        'Rs ${b.total.toStringAsFixed(0)} · ${b.status}',
      ],
    );
  }
}
