import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/entity_photo.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../core/media/entity_media.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../features/invoices/receipt_service.dart';
import '../../l10n/app_copy.dart';
import 'create_bill_dialog.dart';

class KhataPage extends ConsumerWidget {
  const KhataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(khataRepoProvider);

    return KitschBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: Copy.khataTitle,
              actions: [
                KitschIconButton(
                  icon: Icons.person_add,
                  tooltip: Copy.khataAddParty,
                  onPressed: () => _addParty(context, ref),
                ),
                KitschIconButton(
                  icon: Icons.receipt_long,
                  tooltip: Copy.khataBill,
                  color: Theme.of(context).colorScheme.secondary,
                  onPressed: () => createBillWithInventoryPicker(
                    context,
                    ref,
                    emptyPartiesMessage: Copy.needPartyBill,
                  ),
                ),
                KitschIconButton(
                  icon: Icons.payments,
                  tooltip: Copy.khataPay,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => _addPayment(context, ref),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<Party>>(
                stream: repo.watchParties(),
                builder: (context, snap) {
                  final parties = snap.data ?? [];
                  if (parties.isEmpty) {
                    return const Center(child: Text(Copy.khataEmpty));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: parties.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = parties[i];
                      return KitschSticker(
                        color: p.role == 'customer'
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.secondary,
                        onTap: () => _partyActions(context, ref, p),
                        child: StickerRow(
                          leading: EntityPhotoThumb(
                            path: p.imagePath,
                            icon: Icons.person_outline,
                          ),
                          title: p.name,
                          subtitle:
                              '${p.role == 'customer' ? Copy.customer : p.role == 'supplier' ? Copy.supplier : Copy.bothRoles}'
                              ' · ${p.qrCode}'
                              '${p.phone != null ? ' · ${p.phone}' : ''}'
                              '${p.city != null ? ' · ${p.city}' : ''}',
                          trailing: Text(
                            'Rs ${p.balance.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(thickness: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bills',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: StreamBuilder<List<Bill>>(
                stream: repo.watchBills(),
                builder: (context, snap) {
                  final bills = snap.data ?? [];
                  if (bills.isEmpty) {
                    return const Center(child: Text('Abhi koi bill nahi'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bills.length,
                    itemBuilder: (context, i) {
                      final b = bills[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: KitschSticker(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shadowDx: 2,
                          shadowDy: 2,
                          borderWidth: 2.5,
                          onTap: () => _billActions(context, ref, b),
                          child: StickerRow(
                            title:
                                '${b.billNo ?? 'Bill'} · Rs ${b.total.toStringAsFixed(0)}',
                            subtitle: billStatusLabel(b.status),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                          ),
                        ),
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

  Future<void> _partyActions(
    BuildContext context,
    WidgetRef ref,
    Party p,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(Copy.details),
              subtitle: const Text(Copy.khataPartyDetails),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            ListTile(
              leading: const KitschQrIcon(),
              title: const Text(Copy.showQr),
              subtitle: Text(p.qrCode),
              onTap: () => Navigator.pop(ctx, 'qr'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text(Copy.khataEditParty),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
              title: const Text(Copy.delete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'details') {
      context.push('/udhaar/party/${p.id}');
      return;
    }
    if (action == 'qr') {
      await showEntityQr(
        context,
        title: Copy.qrOfParty,
        qrCode: p.qrCode,
        detailLines: [
          p.name,
          p.role,
          if (p.phone != null) '${Copy.phone}: ${p.phone}',
          if (p.city != null) '${Copy.city}: ${p.city}',
          'Baqaya: Rs ${p.balance.toStringAsFixed(0)}',
        ],
      );
      return;
    }
    if (action == 'delete') {
      await ref.read(khataRepoProvider).softDeleteParty(p.id);
      if (context.mounted) showOk(context, Copy.deletedOk);
      return;
    }

    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone ?? '');
    final city = TextEditingController(text: p.city ?? '');
    var imagePath = p.imagePath;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.khataEditParty),
          content: dialogForm([
            EntityPhotoPicker(
              path: imagePath,
              kind: 'parties',
              entityId: p.id,
              label: 'Party photo',
              placeholderIcon: Icons.person_outline,
              onChanged: (v) => setLocal(() => imagePath = v),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: Copy.name),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: Copy.phone),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: Copy.city),
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
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(khataRepoProvider).updateParty(
            id: p.id,
            name: name.text.trim(),
            phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
            city: city.text.trim().isEmpty ? null : city.text.trim(),
            imagePath: imagePath,
            clearImage: imagePath == null && p.imagePath != null,
          );
      if (context.mounted) showOk(context, Copy.partySaved);
    }
  }

  Future<void> _billActions(
    BuildContext context,
    WidgetRef ref,
    Bill b,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(Copy.details),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print receipt'),
              onTap: () => Navigator.pop(ctx, 'receipt'),
            ),
            ListTile(
              leading: const KitschQrIcon(),
              title: const Text(Copy.showQr),
              onTap: () => Navigator.pop(ctx, 'qr'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'details':
        context.push('/udhaar/bill/${b.id}');
      case 'receipt':
        await openBillReceipt(context, ref, b);
      case 'qr':
        await showEntityQr(
          context,
          title: Copy.qrOfBill,
          qrCode: b.qrCode,
          detailLines: [
            b.billNo ?? b.id,
            billStatusLabel(b.status),
            'By: ${ownerDisplayName(b.createdByOwnerId)}',
          ],
        );
    }
  }

  Future<void> _addParty(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    var role = 'customer';
    String? imagePath;
    final photoId = EntityMedia.tempId();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.khataAddParty),
          content: dialogForm([
            EntityPhotoPicker(
              path: imagePath,
              kind: 'parties',
              entityId: photoId,
              label: 'Party photo',
              placeholderIcon: Icons.person_outline,
              onChanged: (v) => setLocal(() => imagePath = v),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: Copy.name),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: Copy.phone),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: Copy.address),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: Copy.city),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(role),
              initialValue: role,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text(Copy.customer)),
                DropdownMenuItem(value: 'supplier', child: Text(Copy.supplier)),
                DropdownMenuItem(value: 'both', child: Text(Copy.bothRoles)),
              ],
              onChanged: (v) => setLocal(() => role = v!),
              decoration: const InputDecoration(labelText: Copy.role),
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
    if (ok != true || name.text.trim().isEmpty) return;
    final id = await ref.read(khataRepoProvider).addParty(
          name: name.text.trim(),
          role: role,
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          address: address.text.trim().isEmpty ? null : address.text.trim(),
          city: city.text.trim().isEmpty ? null : city.text.trim(),
          imagePath: imagePath,
        );
    if (imagePath != null) {
      final renamed = await EntityMedia.renameTemp(
        kind: 'parties',
        tempPath: imagePath!,
        entityId: id,
      );
      if (renamed != null && renamed != imagePath) {
        await ref.read(khataRepoProvider).updateParty(id: id, imagePath: renamed);
      }
    }
    final party = await ref.read(khataRepoProvider).partyById(id);
    if (!context.mounted) return;
    showOk(context, Copy.partySaved);
    if (party != null) {
      await showEntityQr(
        context,
        title: Copy.qrOfParty,
        qrCode: party.qrCode,
        detailLines: [party.name, party.role],
      );
    }
  }

  Future<void> _addPayment(BuildContext context, WidgetRef ref) async {
    final parties = await ref.read(khataRepoProvider).watchParties().first;
    if (!context.mounted) return;
    if (parties.isEmpty) {
      showNeed(context, Copy.needPartyPay);
      return;
    }
    var partyId = parties.first.id;
    var method = 'cash';
    final amount = TextEditingController();
    final owner = ref.read(authControllerProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.khataPay),
          content: dialogForm([
            DropdownButtonFormField<String>(
              key: ValueKey(partyId),
              initialValue: partyId,
              isExpanded: true,
              items: parties
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setLocal(() => partyId = v!),
              decoration: const InputDecoration(labelText: Copy.party),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('pay-$method'),
              initialValue: method,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text(Copy.payCash)),
                DropdownMenuItem(value: 'online', child: Text(Copy.payOnline)),
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
    final amt = double.tryParse(amount.text) ?? 0;
    if (amt <= 0) {
      if (context.mounted) showNeed(context, 'Amount likho');
      return;
    }
    try {
      await ref.read(khataRepoProvider).recordPayment(
            partyId: partyId,
            amount: amt,
            method: method,
            createdByOwnerId: owner?.ownerId,
          );
      if (!context.mounted) return;
      showOk(context, Copy.paymentSaved);
      final party = await ref.read(khataRepoProvider).partyById(partyId);
      if (!context.mounted) return;
      await openReceiptPreview(
        context,
        ReceiptDraft(
          id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
          headline: 'PAYMENT RECEIPT',
          ownerName: owner?.displayName,
          at: DateTime.now(),
          qrPayload: party?.qrCode,
          mood: ReceiptMood.income,
          meta: [
            ('Party', party?.name ?? partyId),
            ('Amount', 'Rs ${amt.toStringAsFixed(0)}'),
            ('Method', method),
            ('Baqaya ab', 'Rs ${(party?.balance ?? 0).toStringAsFixed(0)}'),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showFail(context, '$e');
    }
  }
}
