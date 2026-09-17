import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/entity_photo.dart';
import '../../brand/ui_helpers.dart';
import '../../core/constants/catalog_options.dart';
import '../../core/media/entity_media.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../l10n/app_copy.dart';

/// Shared Bill banao flow: party → sale/buy → searchable inventory item.
Future<void> createBillWithInventoryPicker(
  BuildContext context,
  WidgetRef ref, {
  required String emptyPartiesMessage,
  String dialogTitle = Copy.khataBill,
}) async {
  final parties = await ref.read(khataRepoProvider).watchParties().first;
  final allItems = await ref.read(inventoryRepoProvider).watchItems().first;
  final stockMap = Map<String, double>.from(
    await ref.read(inventoryRepoProvider).totalsByItem(),
  );
  if (!context.mounted) return;
  if (parties.isEmpty) {
    showNeed(context, emptyPartiesMessage);
    return;
  }

  var partyId = parties.first.id;
  var kind = 'sale';
  var paymentMethod = 'credit';
  Item? selected;
  var items = List<Item>.from(allItems);
  final qty = TextEditingController(text: '1');
  final price = TextEditingController(text: '0');
  final concession = TextEditingController(text: '0');
  final owner = ref.read(authControllerProvider);

  List<Item> filteredForKind(String k, String q) {
    final query = q.trim().toLowerCase();
    Iterable<Item> base = items;
    if (k == 'sale') {
      base = base.where((i) => (stockMap[i.id] ?? 0) > 0);
    }
    if (query.isNotEmpty) {
      base = base.where((i) => i.name.toLowerCase().contains(query));
    }
    return base.toList();
  }

  void applyItemPrice(Item item, void Function(void Function()) setLocal) {
    selected = item;
    final p = kind == 'sale' ? item.salePrice : item.costPrice;
    price.text = p > 0 ? p.toStringAsFixed(0) : '0';
    setLocal(() {});
  }

  Future<Item?> quickAddItem(BuildContext dialogCtx) async {
    final name = TextEditingController();
    final saleCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final discount = TextEditingController();
    final notes = TextEditingController();
    String? category;
    String? unit = 'pcs';
    double? reorder;
    String? imagePath;
    final photoEntityId = 'tmp-${DateTime.now().millisecondsSinceEpoch}';
    final ok = await showDialog<bool>(
      context: dialogCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final retail = double.tryParse(saleCtrl.text);
          final buy = double.tryParse(costCtrl.text);
          final disc = double.tryParse(discount.text) ?? 0;
          String? marginText;
          if (retail != null && buy != null && retail > 0) {
            final afterDisc = retail * (1 - disc / 100);
            final m = ((afterDisc - buy) / afterDisc) * 100;
            marginText =
                '${Copy.marginLabel}: ${m.toStringAsFixed(1)}% (after discount)';
          }
          return AlertDialog(
            title: const Text(Copy.stockAdd),
            content: dialogForm([
              EntityPhotoPicker(
                path: imagePath,
                kind: 'items',
                entityId: photoEntityId,
                label: 'Product photo',
                placeholderIcon: Icons.inventory_2_outlined,
                onChanged: (p) => setLocal(() => imagePath = p),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: Copy.name,
                  hintText: Copy.nameHint,
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('cat-$category'),
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: Copy.category,
                  hintText: Copy.categoryHint,
                ),
                items: [
                  for (final c in CatalogOptions.categories)
                    DropdownMenuItem(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => category = v),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('unit-$unit'),
                initialValue: unit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: Copy.unit,
                  hintText: Copy.unitHint,
                ),
                items: [
                  for (final u in CatalogOptions.units)
                    DropdownMenuItem(
                      value: u,
                      child: Text(u, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => unit = v),
              ),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: Copy.costPrice,
                  hintText: Copy.costPriceHint,
                ),
              ),
              TextField(
                controller: saleCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: Copy.price,
                  hintText: Copy.priceHint,
                ),
              ),
              TextField(
                controller: discount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: Copy.discount,
                  hintText: Copy.discountHint,
                ),
              ),
              if (marginText != null)
                Text(marginText, style: Theme.of(ctx).textTheme.bodySmall),
              DropdownButtonFormField<double>(
                key: ValueKey('re-$reorder'),
                initialValue: reorder != null &&
                        CatalogOptions.reorderPresets.contains(reorder)
                    ? reorder
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: Copy.reorderLevel,
                  hintText: Copy.reorderHint,
                ),
                items: [
                  for (final r in CatalogOptions.reorderPresets)
                    DropdownMenuItem(
                      value: r,
                      child: Text(r.toStringAsFixed(0)),
                    ),
                ],
                onChanged: (v) => setLocal(() => reorder = v),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(
                  labelText: Copy.note,
                  hintText: Copy.noteHint,
                ),
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
          );
        },
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return null;
    if (unit == null || unit!.isEmpty) {
      if (dialogCtx.mounted) showNeed(dialogCtx, 'Pick a unit');
      return null;
    }
    final discNote = discount.text.trim().isEmpty
        ? null
        : 'discount:${discount.text.trim()}';
    final mergedNote = [
      if (notes.text.trim().isNotEmpty) notes.text.trim(),
      ?discNote,
    ].join(' | ');
    final repo = ref.read(inventoryRepoProvider);
    final id = await repo.addItem(
      name: name.text.trim(),
      category: category,
      unit: unit!,
      salePrice: double.tryParse(saleCtrl.text) ?? 0,
      costPrice: double.tryParse(costCtrl.text) ?? 0,
      reorderLevel: reorder ?? 0,
      notes: mergedNote.isEmpty ? null : mergedNote,
      imagePath: imagePath,
      actorOwnerId: owner?.ownerId,
    );
    if (imagePath != null) {
      final renamed = await EntityMedia.renameTemp(
        kind: 'items',
        tempPath: imagePath!,
        entityId: id,
      );
      if (renamed != null && renamed != imagePath) {
        await repo.updateItem(id: id, imagePath: renamed);
      }
    }
    return repo.itemById(id);
  }

  Future<void> pickItem(
    BuildContext dialogCtx,
    void Function(void Function()) setLocal,
  ) async {
    final queryCtrl = TextEditingController();
    final picked = await showModalBottomSheet<Object>(
      context: dialogCtx,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setMenu) {
            final visible = filteredForKind(kind, queryCtrl.text);
            final bottomInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetCtx).height * 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        Copy.billItemName,
                        style: Theme.of(sheetCtx).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: queryCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: Copy.billItemSearch,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setMenu(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: const Text(Copy.billAddNewItem),
                            onTap: () {
                              FocusScope.of(sheetCtx).unfocus();
                              Navigator.pop(sheetCtx, '__add_new__');
                            },
                          ),
                          if (visible.isEmpty)
                            const ListTile(
                              title: Text(
                                'Koi item nahi — Add new use karo',
                              ),
                            ),
                          for (final item in visible)
                            ListTile(
                              leading: EntityPhotoThumb(
                                path: item.imagePath,
                                size: 36,
                                icon: Icons.inventory_2_outlined,
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                'Qty ${(stockMap[item.id] ?? 0).toStringAsFixed(0)}'
                                ' · Rs ${(kind == 'sale' ? item.salePrice : item.costPrice).toStringAsFixed(0)}',
                              ),
                              onTap: () {
                                FocusScope.of(sheetCtx).unfocus();
                                Navigator.pop(sheetCtx, item);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // Dispose after the sheet overlay fully deactivates (avoids _dependents crash).
    WidgetsBinding.instance.addPostFrameCallback((_) => queryCtrl.dispose());
    if (picked == null) return;
    if (picked == '__add_new__') {
      if (!dialogCtx.mounted) return;
      final created = await quickAddItem(dialogCtx);
      if (created == null) return;
      items = [...items, created];
      stockMap[created.id] = stockMap[created.id] ?? 0;
      applyItemPrice(created, setLocal);
      return;
    }
    if (picked is Item) applyItemPrice(picked, setLocal);
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final q = double.tryParse(qty.text) ?? 0;
        final p = double.tryParse(price.text) ?? 0;
        final c = double.tryParse(concession.text) ?? 0;
        final lineTotal = (q * p) - (c * q);

        return AlertDialog(
          title: Text(dialogTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: dialogForm([
              DropdownButtonFormField<String>(
                key: ValueKey('party-$partyId'),
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
                key: ValueKey('kind-$kind'),
                initialValue: kind,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'sale', child: Text(Copy.sale)),
                  DropdownMenuItem(
                    value: 'purchase',
                    child: Text(Copy.purchase),
                  ),
                ],
                onChanged: (v) {
                  setLocal(() {
                    kind = v!;
                    selected = null;
                    price.text = '0';
                  });
                },
                decoration: const InputDecoration(labelText: Copy.billKind),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('pay-$paymentMethod'),
                initialValue: paymentMethod,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'credit',
                    child: Text(Copy.payCredit),
                  ),
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text(Copy.payCash),
                  ),
                  DropdownMenuItem(
                    value: 'online',
                    child: Text(Copy.payOnline),
                  ),
                ],
                onChanged: (v) => setLocal(() => paymentMethod = v!),
                decoration: const InputDecoration(labelText: Copy.billPayMethod),
              ),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: Copy.billItemName,
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: InkWell(
                  onTap: () => pickItem(ctx, setLocal),
                  child: Text(
                    selected?.name ?? 'Choose item',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                          color: selected == null
                              ? Theme.of(ctx).hintColor
                              : null,
                        ),
                  ),
                ),
              ),
              if (selected != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    EntityPhotoThumb(
                      path: selected!.imagePath,
                      size: 52,
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: qty,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                        onChanged: (_) => setLocal(() {}),
                        decoration: const InputDecoration(
                          labelText: Copy.qty,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  kind == 'sale'
                      ? 'Stock: ${(stockMap[selected!.id] ?? 0).toStringAsFixed(0)} · Sell Rs ${selected!.salePrice.toStringAsFixed(0)}'
                      : 'Stock: ${(stockMap[selected!.id] ?? 0).toStringAsFixed(0)} · Buy Rs ${selected!.costPrice.toStringAsFixed(0)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: kind == 'sale' ? Copy.price : Copy.costPrice,
                ),
              ),
              TextField(
                controller: concession,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: Copy.billConcession,
                ),
              ),
              Text(
                '${Copy.billLineTotal}: Rs ${lineTotal.toStringAsFixed(0)}'
                '${c > 0 ? '  (Rs ${c.toStringAsFixed(0)} × ${q.toStringAsFixed(0)} off)' : ''}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(Copy.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (selected == null) {
                  showNeed(ctx, 'Pehle item choose karo');
                  return;
                }
                if (kind == 'sale') {
                  final avail = stockMap[selected!.id] ?? 0;
                  final want = double.tryParse(qty.text) ?? 0;
                  if (want > avail + 1e-9) {
                    showNeed(
                      ctx,
                      'Stock kam hai (available ${avail.toStringAsFixed(0)})',
                    );
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text(Copy.save),
            ),
          ],
        );
      },
    ),
  );

  final qVal = double.tryParse(qty.text) ?? 1;
  final pVal = double.tryParse(price.text) ?? 0;
  final cVal = double.tryParse(concession.text) ?? 0;
  final chosen = selected;
  qty.dispose();
  price.dispose();
  concession.dispose();

  if (ok != true || chosen == null) return;

  try {
    final billId = await ref.read(khataRepoProvider).createBill(
          partyId: partyId,
          kind: kind,
          paymentMethod: paymentMethod,
          createdByOwnerId: owner?.ownerId,
          lines: [
            (
              description: chosen.name,
              itemId: chosen.id,
              qty: qVal,
              unitPrice: pVal,
              unit: chosen.unit,
              lineDiscount: cVal * qVal,
            ),
          ],
        );
    if (!context.mounted) return;
    final msg = paymentMethod == 'credit'
        ? Copy.billSavedCredit
        : Copy.billSavedCash;
    showOk(context, msg);
    final bill = await ref.read(khataRepoProvider).billById(billId);
    if (bill != null && context.mounted) {
      await openBillReceipt(context, ref, bill);
    }
  } catch (e) {
    if (context.mounted) showFail(context, '$e');
  }
}
