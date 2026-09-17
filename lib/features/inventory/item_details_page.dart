import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/entity_photo.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class ItemDetailsPage extends ConsumerWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(inventoryRepoProvider);

    return FutureBuilder<Item?>(
      future: repo.itemById(itemId),
      builder: (context, itemSnap) {
        final item = itemSnap.data;
        if (itemSnap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.stockDetails),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (item == null) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.stockDetails),
            body: const Center(child: Text('Product not found')),
          );
        }

        final margin = item.salePrice > 0 && item.costPrice > 0
            ? ((item.salePrice - item.costPrice) / item.salePrice) * 100
            : null;

        return Scaffold(
          appBar: kitschAppBar(
            context,
            title: item.name,
            actions: [
              IconButton(
                icon: const KitschQrIcon(),
                tooltip: Copy.showQr,
                onPressed: () => showEntityQr(
                  context,
                  title: Copy.qrOfItem,
                  qrCode: item.qrCode,
                  qrOnly: true,
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
                          path: item.imagePath,
                          size: 120,
                          radius: 18,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(item.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('${Copy.qrCode}: ${item.qrCode}'),
                      if (item.category != null)
                        Text('${Copy.category}: ${item.category}'),
                      Text('${Copy.unit}: ${item.unit}'),
                      Text(
                        '${Copy.costPrice}: Rs ${item.costPrice.toStringAsFixed(0)}',
                      ),
                      Text(
                        '${Copy.price}: Rs ${item.salePrice.toStringAsFixed(0)}',
                      ),
                      if (margin != null)
                        Text(
                          '${Copy.marginLabel}: ${margin.toStringAsFixed(1)}%',
                        ),
                      if (item.reorderLevel > 0)
                        Text(
                          '${Copy.reorderLevel}: ${item.reorderLevel.toStringAsFixed(0)}',
                        ),
                      if (item.notes != null) Text('${Copy.note}: ${item.notes}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  Copy.detailsStockByPlace,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: Future.wait([
                    repo.watchLocations().first,
                    repo.qtyByLocation(item.id),
                  ]),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final locs = snap.data![0] as List<Location>;
                    final qtys = snap.data![1] as Map<String, double>;
                    return Column(
                      children: locs.map((l) {
                        final q = qtys[l.id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KitschSticker(
                            shadowDx: 2,
                            shadowDy: 2,
                            borderWidth: 2.5,
                            color: Theme.of(context).colorScheme.secondary,
                            child: StickerRow(
                              title: l.name,
                              subtitle: l.kind,
                              trailing: Text(
                                q.toStringAsFixed(q == q.roundToDouble() ? 0 : 1),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  Copy.detailsHistory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<StockEvent>>(
                  stream: repo.watchEventsForItem(item.id),
                  builder: (context, snap) {
                    final events = snap.data ?? [];
                    if (events.isEmpty) {
                      return const Text(Copy.detailsEmptyHistory);
                    }
                    return Column(
                      children: events.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KitschSticker(
                            shadowDx: 2,
                            shadowDy: 2,
                            borderWidth: 2.5,
                            child: StickerRow(
                              title: '${e.type} · ${e.qty}',
                              subtitle:
                                  '${e.at.toString().substring(0, 16)}${e.note != null ? ' · ${e.note}' : ''}',
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  Copy.detailsCustomers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  Copy.detailsSuppliers,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: repo.partyLinksForItem(item.id),
                  builder: (context, snap) {
                    final rows = snap.data ?? [];
                    if (rows.isEmpty) {
                      return const Text(Copy.detailsEmptyParties);
                    }
                    return Column(
                      children: rows.map((r) {
                        final isSale = r.bill.kind == 'sale';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KitschSticker(
                            shadowDx: 2,
                            shadowDy: 2,
                            borderWidth: 2.5,
                            color: isSale
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.primary,
                            child: StickerRow(
                              title: r.party?.name ?? r.bill.partyId,
                              subtitle:
                                  '${isSale ? Copy.customer : Copy.supplier}'
                                  ' · ${r.line.qty} @ ${r.line.unitPrice}'
                                  ' · ${r.bill.billNo ?? r.bill.id}',
                              trailing: Text(
                                r.bill.createdAt.toString().substring(0, 10),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
