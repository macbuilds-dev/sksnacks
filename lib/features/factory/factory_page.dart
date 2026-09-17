import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/invoices/receipt_preview_page.dart';
import '../../features/invoices/receipt_service.dart';
import '../../l10n/app_copy.dart';

class FactoryPage extends ConsumerWidget {
  const FactoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(factoryRepoProvider);

    return KitschBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: Copy.factoryTitle,
              actions: [
                KitschIconButton(
                  icon: Icons.add,
                  tooltip: Copy.factoryAddRecipe,
                  onPressed: () => _upsertRecipe(context, ref),
                ),
                KitschIconButton(
                  icon: Icons.precision_manufacturing,
                  tooltip: Copy.factoryProduce,
                  color: Theme.of(context).colorScheme.secondary,
                  onPressed: () => _produce(context, ref),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<BomRecipe>>(
                stream: repo.watchRecipes(),
                builder: (context, snap) {
                  final recipes = snap.data ?? [];
                  if (recipes.isEmpty) {
                    return const Center(child: Text(Copy.factoryEmpty));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: recipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = recipes[i];
                      return KitschSticker(
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () => _recipeActions(context, ref, r),
                        child: StickerRow(
                          title: r.name,
                          subtitle:
                              'Ek dafa mein ${r.yieldQty.toStringAsFixed(0)} banta hai',
                          trailing: const Icon(Icons.chevron_right),
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

  Future<void> _recipeActions(
    BuildContext context,
    WidgetRef ref,
    BomRecipe r,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.precision_manufacturing),
              title: const Text(Copy.factoryProduce),
              onTap: () => Navigator.pop(ctx, 'produce'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(Copy.details),
              subtitle: const Text(Copy.factoryRecipeDetails),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text(Copy.factoryEditRecipe),
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
      case 'produce':
        await _produce(context, ref, recipe: r);
      case 'details':
        context.push('/factory/recipe/${r.id}');
      case 'edit':
        await _upsertRecipe(context, ref, existing: r);
      case 'delete':
        await ref.read(factoryRepoProvider).softDeleteRecipe(r.id);
    }
  }

  Future<void> _upsertRecipe(
    BuildContext context,
    WidgetRef ref, {
    BomRecipe? existing,
  }) async {
    final items = await ref.read(inventoryRepoProvider).watchItems().first;
    if (!context.mounted) return;
    if (items.length < 2) {
      showNeed(context, Copy.needTwoItems);
      return;
    }

    final name = TextEditingController(text: existing?.name ?? '');
    final yieldQty = TextEditingController(
      text: existing != null ? existing.yieldQty.toStringAsFixed(0) : '1',
    );
    var finishedId = existing?.finishedItemId ?? items.last.id;

    var lines = <({String key, String itemId, TextEditingController qty})>[];
    if (existing != null) {
      final bomLines =
          await ref.read(factoryRepoProvider).linesFor(existing.id);
      for (final l in bomLines) {
        lines.add((
          key: const Uuid().v4(),
          itemId: l.ingredientItemId,
          qty: TextEditingController(
            text: l.qty.toStringAsFixed(l.qty == l.qty.roundToDouble() ? 0 : 1),
          ),
        ));
      }
    }
    while (lines.length < 2) {
      final pick = items.firstWhere(
        (e) => e.id != finishedId && lines.every((l) => l.itemId != e.id),
        orElse: () => items.first,
      );
      lines.add((
        key: const Uuid().v4(),
        itemId: pick.id,
        qty: TextEditingController(text: '1'),
      ));
    }
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? Copy.factoryAddRecipe
                  : Copy.factoryEditRecipe,
            ),
            content: dialogForm([
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: Copy.name,
                  hintText: 'e.g. Nimco Mix nuskha',
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('fin-$finishedId'),
                initialValue: finishedId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: Copy.finishedItem),
                items: [
                  for (final e in items)
                    DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => finishedId = v!),
              ),
              TextField(
                controller: yieldQty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: Copy.yieldQty),
              ),
              Text(
                'Saman (kam az kam 2)',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              for (var i = 0; i < lines.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('ing-${lines[i].key}'),
                        initialValue: lines[i].itemId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '${Copy.ingredient} ${i + 1}',
                        ),
                        items: [
                          for (final e in items)
                            DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                e.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setLocal(() {
                          lines[i] = (
                            key: lines[i].key,
                            itemId: v!,
                            qty: lines[i].qty,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lines[i].qty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: Copy.qty,
                        ),
                      ),
                    ),
                    if (lines.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setLocal(() {
                          lines[i].qty.dispose();
                          lines = [...lines]..removeAt(i);
                        }),
                      ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setLocal(() {
                    final pick = items.firstWhere(
                      (e) =>
                          e.id != finishedId &&
                          lines.every((l) => l.itemId != e.id),
                      orElse: () => items.first,
                    );
                    lines = [
                      ...lines,
                      (
                        key: const Uuid().v4(),
                        itemId: pick.id,
                        qty: TextEditingController(text: '1'),
                      ),
                    ];
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text(Copy.addIngredient),
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

    if (ok != true) return;
    if (name.text.trim().isEmpty) return;
    if (lines.length < 2) {
      if (context.mounted) showNeed(context, Copy.needTwoIngredients);
      return;
    }

    final payload = [
      for (final l in lines)
        (
          ingredientItemId: l.itemId,
          qty: double.tryParse(l.qty.text) ?? 1,
          unit: null,
          wasteFactor: 0.0,
        ),
    ];

    final repo = ref.read(factoryRepoProvider);
    if (existing == null) {
      await repo.addRecipe(
        name: name.text.trim(),
        finishedItemId: finishedId,
        yieldQty: double.tryParse(yieldQty.text) ?? 1,
        lines: payload,
      );
    } else {
      await repo.updateRecipe(
        id: existing.id,
        name: name.text.trim(),
        finishedItemId: finishedId,
        yieldQty: double.tryParse(yieldQty.text) ?? 1,
        lines: payload,
      );
    }
    if (context.mounted) showOk(context, 'Nuskha save ho gaya');
  }

  Future<void> _produce(
    BuildContext context,
    WidgetRef ref, {
    BomRecipe? recipe,
  }) async {
    final recipes = recipe != null
        ? [recipe]
        : await ref.read(factoryRepoProvider).watchRecipes().first;
    final locs = await ref.read(inventoryRepoProvider).watchLocations().first;
    if (!context.mounted) return;
    if (recipes.isEmpty || locs.isEmpty) {
      showNeed(
        context,
        recipes.isEmpty ? Copy.needRecipe : Copy.needLocation,
      );
      return;
    }
    final factoryLoc = locs.firstWhere(
      (l) => l.kind == 'factory',
      orElse: () => locs.first,
    );
    var recipeId = recipes.first.id;
    final batches = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.factoryProduce),
          content: dialogForm([
            DropdownButtonFormField<String>(
              key: ValueKey(recipeId),
              initialValue: recipeId,
              isExpanded: true,
              items: recipes
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setLocal(() => recipeId = v!),
              decoration: const InputDecoration(labelText: Copy.recipe),
            ),
            TextField(
              controller: batches,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: Copy.batches),
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
    final batchCount = double.tryParse(batches.text) ?? 1;
    try {
      final runId = await ref.read(factoryRepoProvider).runProduction(
            recipeId: recipeId,
            factoryLocationId: factoryLoc.id,
            batches: batchCount,
            actorOwnerId: owner?.ownerId,
          );
      final r = await ref.read(factoryRepoProvider).recipeById(recipeId);
      if (!context.mounted) return;
      showOk(context, 'Production ho gaya · stock update');
      await openReceiptPreview(
        context,
        ReceiptDraft(
          id: runId,
          headline: 'PRODUCTION RECEIPT',
          ownerName: owner?.displayName,
          at: DateTime.now(),
          mood: ReceiptMood.produce,
          meta: [
            ('Nuskha', r?.name ?? recipeId),
            ('Kitni dafa', batchCount.toStringAsFixed(0)),
            ('Jagah', factoryLoc.name),
          ],
          totals: [
            (
              'Tayyar',
              '${((r?.yieldQty ?? 0) * batchCount).toStringAsFixed(0)} units'
            ),
          ],
        ),
        syncCollection: 'production_runs',
      );
    } catch (e) {
      if (context.mounted) showFail(context, '$e');
    }
  }
}
