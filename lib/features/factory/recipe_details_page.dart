import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class RecipeDetailsPage extends ConsumerWidget {
  const RecipeDetailsPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factory = ref.watch(factoryRepoProvider);
    final inv = ref.watch(inventoryRepoProvider);

    return FutureBuilder<BomRecipe?>(
      future: factory.recipeById(recipeId),
      builder: (context, snap) {
        final r = snap.data;
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.factoryRecipeDetails),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (r == null) {
          return Scaffold(
            appBar: kitschAppBar(context, title: Copy.factoryRecipeDetails),
            body: const Center(child: Text('Nuskha nahi mila')),
          );
        }

        return Scaffold(
          appBar: kitschAppBar(context, title: r.name),
          body: KitschBackdrop(
            child: FutureBuilder(
              future: Future.wait([
                factory.linesFor(r.id),
                inv.watchItems().first,
              ]),
              builder: (context, dataSnap) {
                if (!dataSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lines = dataSnap.data![0] as List<BomLine>;
                final items = dataSnap.data![1] as List<Item>;
                final byId = {for (final i in items) i.id: i};
                final finished = byId[r.finishedItemId];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    KitschSticker(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            '${Copy.finishedItem}: ${finished?.name ?? r.finishedItemId}',
                          ),
                          Text(
                            '${Copy.yieldQty}: ${r.yieldQty.toStringAsFixed(r.yieldQty == r.yieldQty.roundToDouble() ? 0 : 1)}'
                            '${r.yieldUnit != null ? ' ${r.yieldUnit}' : ''}',
                          ),
                          if (r.notes != null) Text('${Copy.note}: ${r.notes}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Saman jo lagega',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KitschSticker(
                          color: Theme.of(context).colorScheme.secondary,
                          shadowDx: 2,
                          shadowDy: 2,
                          borderWidth: 2.5,
                          child: StickerRow(
                            title: byId[l.ingredientItemId]?.name ??
                                l.ingredientItemId,
                            subtitle: byId[l.ingredientItemId]?.unit,
                            trailing: Text(
                              l.qty.toStringAsFixed(
                                l.qty == l.qty.roundToDouble() ? 0 : 1,
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
