import 'package:drift/drift.dart';

import '../../data/local/app_database.dart';

/// Canonical location ids so reinstall/seed never clones cloud rows.
const kLocFactory = 'loc_factory';
const kLocShop = 'loc_shop';
const kLocGodaam = 'loc_godaam';
const kLocProcessing = 'loc_processing';

/// Seeds Factory, Shop, Godaam, Processing with stable ids (idempotent).
Future<void> seedIfEmpty(AppDatabase db) async {
  final now = DateTime.now();
  final seeds = <({String id, String name, String kind, int sort})>[
    (id: kLocFactory, name: 'Factory', kind: 'factory', sort: 0),
    (id: kLocShop, name: 'Shop', kind: 'shop', sort: 1),
    (id: kLocGodaam, name: 'Godaam', kind: 'godaam', sort: 2),
    (id: kLocProcessing, name: 'Processing', kind: 'other', sort: 3),
  ];

  final existing = await db.select(db.locations).get();
  final active = existing.where((e) => e.isActive).toList();

  for (final s in seeds) {
    if (existing.any((e) => e.id == s.id)) continue;

    final already =
        active.any((e) => e.kind == s.kind && s.kind != 'other') ||
        active.any((e) => e.name.toLowerCase() == s.name.toLowerCase());
    if (already) continue;

    await db.into(db.locations).insert(
          LocationsCompanion.insert(
            id: s.id,
            name: s.name,
            kind: s.kind,
            sortOrder: Value(s.sort),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
