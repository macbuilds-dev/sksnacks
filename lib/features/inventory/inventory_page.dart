import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/entity_photo.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../core/constants/catalog_options.dart';
import '../../core/media/entity_media.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../features/invoices/receipt_service.dart';
import '../../l10n/app_copy.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String? _locationFilter;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(inventoryRepoProvider);

    return KitschBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: Copy.stockTitle,
              actions: [
                KitschIconButton(
                  icon: Icons.add,
                  tooltip: Copy.stockAdd,
                  onPressed: () => _upsertItem(context),
                ),
                KitschIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: Copy.stockMove,
                  color: Theme.of(context).colorScheme.secondary,
                  onPressed: () => _moveStock(context),
                ),
              ],
            ),
            StreamBuilder<List<Location>>(
              stream: repo.watchLocations(),
              builder: (context, snap) {
                final locs = snap.data ?? [];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(Copy.allLocations),
                        selected: _locationFilter == null,
                        onSelected: (_) =>
                            setState(() => _locationFilter = null),
                      ),
                      ...locs.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(l.name),
                            selected: _locationFilter == l.id,
                            onSelected: (_) =>
                                setState(() => _locationFilter = l.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Item>>(
                stream: repo.watchItems(),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text(Copy.stockEmpty));
                  }
                  return FutureBuilder<Map<String, double>>(
                    future: repo.totalsByItem(),
                    builder: (context, totSnap) {
                      final totals = totSnap.data ?? {};
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return FutureBuilder<double>(
                            future: _locationFilter == null
                                ? Future.value(totals[item.id] ?? 0)
                                : repo.qtyAt(
                                    itemId: item.id,
                                    locationId: _locationFilter!,
                                  ),
                            builder: (context, q) {
                              final qty = q.data ?? 0;
                              return KitschSticker(
                                onTap: () => _itemActions(context, item),
                                child: StickerRow(
                                  leading: EntityPhotoThumb(
                                    path: item.imagePath,
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                  title: item.name,
                                  subtitle: [
                                    if (item.category != null) item.category!,
                                    item.unit,
                                    'Rs ${item.salePrice.toStringAsFixed(0)} / ${item.unit}',
                                  ].join(' · '),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        qty.toStringAsFixed(
                                          qty == qty.roundToDouble() ? 0 : 1,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                      Text(
                                        'Rs ${(qty * item.salePrice).toStringAsFixed(0)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
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

  Future<void> _itemActions(BuildContext context, Item item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text(Copy.stockMove),
              subtitle: const Text(Copy.stockMoveHint),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
            ListTile(
              leading: const KitschQrIcon(),
              title: const Text(Copy.showQr),
              subtitle: Text(item.qrCode),
              onTap: () => Navigator.pop(ctx, 'qr'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(Copy.stockDetails),
              subtitle: const Text(Copy.stockDetailsHint),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text(Copy.stockEdit),
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
    switch (action) {
      case 'move':
        await _moveStock(context, presetItem: item);
      case 'qr':
        await showEntityQr(
          context,
          title: Copy.qrOfItem,
          qrCode: item.qrCode,
          qrOnly: true,
        );
      case 'details':
        context.push('/stock/item/${item.id}');
      case 'edit':
        await _upsertItem(context, existing: item);
      case 'delete':
        await ref.read(inventoryRepoProvider).softDeleteItem(item.id);
        if (mounted) setState(() {});
        if (context.mounted) showOk(context, Copy.deletedOk);
    }
  }

  Future<void> _upsertItem(BuildContext context, {Item? existing}) async {
    final name = TextEditingController();
    final sale = TextEditingController();
    final cost = TextEditingController();
    final discount = TextEditingController();
    final notes = TextEditingController();
    String? category = existing?.category;
    String? unit = existing?.unit;
    double? reorder = existing?.reorderLevel == 0 ? null : existing?.reorderLevel;
    var imagePath = existing?.imagePath;
    final photoEntityId = existing?.id ?? EntityMedia.tempId();

    if (existing != null) {
      name.text = existing.name;
      if (existing.salePrice > 0) {
        sale.text = existing.salePrice.toStringAsFixed(0);
      }
      if (existing.costPrice > 0) {
        cost.text = existing.costPrice.toStringAsFixed(0);
      }
      notes.text = existing.notes ?? '';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final retail = double.tryParse(sale.text);
          final buy = double.tryParse(cost.text);
          final disc = double.tryParse(discount.text) ?? 0;
          String? marginText;
          if (retail != null && buy != null && retail > 0) {
            final afterDisc = retail * (1 - disc / 100);
            final m = ((afterDisc - buy) / afterDisc) * 100;
            marginText =
                '${Copy.marginLabel}: ${m.toStringAsFixed(1)}% (after discount)';
          }

          return AlertDialog(
            title: Text(existing == null ? Copy.stockAdd : Copy.stockEdit),
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
                controller: cost,
                keyboardType: TextInputType.number,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: Copy.costPrice,
                  hintText: Copy.costPriceHint,
                ),
              ),
              TextField(
                controller: sale,
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
    if (ok != true || name.text.trim().isEmpty) return;
    if (unit == null || unit!.isEmpty) {
      if (context.mounted) showNeed(context, 'Pick a unit');
      return;
    }

    final repo = ref.read(inventoryRepoProvider);
    final discNote = discount.text.trim().isEmpty
        ? null
        : 'discount:${discount.text.trim()}';
    final mergedNote = [
      if (notes.text.trim().isNotEmpty) notes.text.trim(),
      ?discNote,
    ].join(' | ');

    if (existing == null) {
      final id = await repo.addItem(
        name: name.text.trim(),
        category: category,
        unit: unit!,
        salePrice: double.tryParse(sale.text) ?? 0,
        costPrice: double.tryParse(cost.text) ?? 0,
        reorderLevel: reorder ?? 0,
        notes: mergedNote.isEmpty ? null : mergedNote,
        imagePath: imagePath,
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
      final created = await repo.itemById(id);
      if (mounted) setState(() {});
      if (!context.mounted) return;
      showOk(context, Copy.itemSaved);
      if (created != null) {
        await showEntityQr(
          context,
          title: Copy.qrOfItem,
          qrCode: created.qrCode,
          qrOnly: true,
        );
      }
    } else {
      await repo.updateItem(
        id: existing.id,
        name: name.text.trim(),
        category: category,
        unit: unit!,
        salePrice: double.tryParse(sale.text) ?? 0,
        costPrice: double.tryParse(cost.text) ?? 0,
        reorderLevel: reorder ?? 0,
        notes: mergedNote.isEmpty ? null : mergedNote,
        imagePath: imagePath,
        clearImage: imagePath == null && existing.imagePath != null,
      );
      if (mounted) setState(() {});
      if (context.mounted) showOk(context, Copy.itemSaved);
    }
  }

  Future<void> _moveStock(BuildContext context, {Item? presetItem}) async {
    final repo = ref.read(inventoryRepoProvider);
    final items = await repo.watchItems().first;
    final locs = await repo.watchLocations().first;
    if (!context.mounted) return;
    if (items.isEmpty || locs.isEmpty) {
      showNeed(
        context,
        items.isEmpty ? Copy.needItemFirst : Copy.needLocation,
      );
      return;
    }

    var itemId = presetItem?.id ?? items.first.id;
    var locId = locs.first.id;
    var toLocId = locs.length > 1 ? locs[1].id : locs.first.id;
    var type = 'purchase';
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final typeMeta = CatalogOptions.moveTypes
              .firstWhere((t) => t.value == type, orElse: () => CatalogOptions.moveTypes.first);
          return AlertDialog(
            title: const Text(Copy.stockMove),
            content: dialogForm([
              Text(
                typeMeta.hint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('type-$type'),
                initialValue: type,
                isExpanded: true,
                items: [
                  for (final t in CatalogOptions.moveTypes)
                    DropdownMenuItem(
                      value: t.value,
                      child: Text(t.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => type = v!),
                decoration: const InputDecoration(labelText: Copy.stockMoveType),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('item-$itemId'),
                initialValue: itemId,
                isExpanded: true,
                items: items
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => itemId = v!),
                decoration: const InputDecoration(labelText: Copy.stockItem),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('loc-$locId-$type'),
                initialValue: locId,
                isExpanded: true,
                items: locs
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => locId = v!),
                decoration: InputDecoration(
                  labelText:
                      type == 'transfer' ? Copy.stockFrom : Copy.stockWhere,
                ),
              ),
              if (type == 'transfer')
                DropdownButtonFormField<String>(
                  key: ValueKey('to-$toLocId'),
                  initialValue: toLocId,
                  isExpanded: true,
                  items: locs
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => toLocId = v!),
                  decoration: const InputDecoration(labelText: Copy.stockTo),
                ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: Copy.qty,
                  hintText: Copy.qtyHint,
                ),
              ),
              TextField(
                controller: noteCtrl,
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

    if (ok == true) {
      final qty = double.tryParse(qtyCtrl.text);
      if (qty == null || qty <= 0) {
        if (context.mounted) showNeed(context, 'Enter a valid quantity');
        return;
      }
      final owner = ref.read(authControllerProvider);
      final item = items.firstWhere((e) => e.id == itemId);
      final fromLoc = locs.firstWhere((e) => e.id == locId);
      final toLoc = type == 'transfer'
          ? locs.firstWhere((e) => e.id == toLocId)
          : null;
      try {
        await repo.applyStockEvent(
          type: type,
          itemId: itemId,
          locationId: locId,
          toLocationId: type == 'transfer' ? toLocId : null,
          qty: qty,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          actorOwnerId: owner?.ownerId,
        );
        if (!mounted) return;
        setState(() {});
        showOk(this.context, Copy.stockMoved);
        final typeLabel = CatalogOptions.moveTypes
            .firstWhere((t) => t.value == type, orElse: () => CatalogOptions.moveTypes.first)
            .label;
        await openReceiptPreview(
          this.context,
          ReceiptDraft(
            id: 'stock_${DateTime.now().millisecondsSinceEpoch}',
            headline: 'STOCK RECEIPT',
            ownerName: owner?.displayName,
            at: DateTime.now(),
            qrPayload: item.qrCode,
            mood: moodForStockType(type),
            meta: [
              ('Action', typeLabel),
              ('Product', item.name),
              ('Qty', qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)),
              ('Where', fromLoc.name),
              if (toLoc != null) ('To', toLoc.name),
              if (noteCtrl.text.trim().isNotEmpty)
                ('Note', noteCtrl.text.trim()),
            ],
          ),
          syncCollection: 'stock_events',
        );
      } catch (e) {
        if (!mounted) return;
        showFail(this.context, '$e');
      }
    }
  }
}
