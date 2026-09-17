import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/app_database.dart';
import 'sync_worker.dart';

/// Collapse duplicate local rows (seed UUID × cloud id) by **hard-deleting**
/// losers after remapping FKs — not soft-hide.
Future<int> dedupeLocalBusinessData(AppDatabase db) async {
  var n = 0;
  n += await _dedupeLocations(db);
  n += await _dedupeItems(db);
  n += await _dedupeParties(db);
  if (n > 0) {
    debugPrint('SyncDedupe hard-removed $n duplicate rows');
  }
  return n;
}

Future<int> _dedupeLocations(AppDatabase db) async {
  final rows = await db.select(db.locations).get();
  final groups = <String, List<Location>>{};
  for (final r in rows) {
    final groupKey = r.kind == 'other'
        ? 'name:${r.name.toLowerCase().replaceAll(' (dup)', '')}'
        : 'kind:${r.kind.toLowerCase()}';
    (groups[groupKey] ??= []).add(r);
  }

  var removed = 0;
  for (final list in groups.values) {
    if (list.length < 2) {
      // Lone inactive "(dup)" leftovers with no sibling — still purge.
      if (list.length == 1 &&
          (!list.first.isActive || list.first.name.contains('(dup)'))) {
        final only = list.first;
        final fallback = rows.where((r) => r.id != only.id && r.isActive);
        if (fallback.isNotEmpty) {
          await _remapLocationId(db, from: only.id, to: fallback.first.id);
        }
        await _hardDeleteLocation(db, only.id);
        removed++;
      }
      continue;
    }

    list.sort((a, b) {
      // Prefer active, then stable loc_*, then oldest.
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      final aStable = a.id.startsWith('loc_') ? 0 : 1;
      final bStable = b.id.startsWith('loc_') ? 0 : 1;
      if (aStable != bStable) return aStable.compareTo(bStable);
      return a.createdAt.compareTo(b.createdAt);
    });
    final keep = list.first;
    // Ensure keeper is active.
    if (!keep.isActive) {
      await (db.update(db.locations)..where((t) => t.id.equals(keep.id)))
          .write(
        LocationsCompanion(
          isActive: const Value(true),
          name: Value(keep.name.replaceAll(' (dup)', '')),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
    for (final loser in list.skip(1)) {
      await _remapLocationId(db, from: loser.id, to: keep.id);
      await _hardDeleteLocation(db, loser.id);
      removed++;
    }
  }
  return removed;
}

Future<void> _hardDeleteLocation(AppDatabase db, String id) async {
  await (db.delete(db.locations)..where((t) => t.id.equals(id))).go();
  await enqueueSync(
    db,
    collection: 'locations',
    docId: id,
    payload: {'_deleted': true},
  );
}

Future<void> _remapLocationId(
  AppDatabase db, {
  required String from,
  required String to,
}) async {
  if (from == to) return;

  final fromBalances = await (db.select(db.stockBalances)
        ..where((t) => t.locationId.equals(from)))
      .get();
  for (final bal in fromBalances) {
    final existing = await (db.select(db.stockBalances)
          ..where(
            (t) => t.itemId.equals(bal.itemId) & t.locationId.equals(to),
          ))
        .getSingleOrNull();
    if (existing == null) {
      await (db.update(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(bal.itemId) & t.locationId.equals(from),
            ))
          .write(StockBalancesCompanion(locationId: Value(to)));
    } else {
      await (db.update(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(bal.itemId) & t.locationId.equals(to),
            ))
          .write(
        StockBalancesCompanion(
          qty: Value(existing.qty + bal.qty),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await (db.delete(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(bal.itemId) & t.locationId.equals(from),
            ))
          .go();
    }
  }

  await (db.update(db.stockEvents)..where((t) => t.locationId.equals(from)))
      .write(StockEventsCompanion(locationId: Value(to)));
  await (db.update(db.stockEvents)..where((t) => t.toLocationId.equals(from)))
      .write(StockEventsCompanion(toLocationId: Value(to)));
  await (db.update(db.bills)..where((t) => t.locationId.equals(from)))
      .write(BillsCompanion(locationId: Value(to)));
  await (db.update(db.cashEntries)..where((t) => t.locationId.equals(from)))
      .write(CashEntriesCompanion(locationId: Value(to)));
  await (db.update(db.dayChecks)..where((t) => t.locationId.equals(from)))
      .write(DayChecksCompanion(locationId: Value(to)));
  await (db.update(db.productionRuns)
        ..where((t) => t.factoryLocationId.equals(from)))
      .write(ProductionRunsCompanion(factoryLocationId: Value(to)));
}

Future<int> _dedupeItems(AppDatabase db) async {
  final rows = await db.select(db.items).get();
  final groups = <String, List<Item>>{};
  for (final r in rows) {
    final raw = r.qrCode.trim();
    if (raw.startsWith('DUP-')) continue;
    final key = raw.isEmpty ? 'id:${r.id}' : raw;
    (groups[key] ??= []).add(r);
  }
  // Also group inactive name+(dup) with active same base name via qr already.

  var removed = 0;
  for (final list in groups.values) {
    if (list.length < 2) continue;
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    final keep = list.first;
    if (!keep.isActive) {
      await (db.update(db.items)..where((t) => t.id.equals(keep.id))).write(
        ItemsCompanion(
          isActive: const Value(true),
          name: Value(keep.name.replaceAll(' (dup)', '')),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
    for (final loser in list.skip(1)) {
      await _remapItemId(db, from: loser.id, to: keep.id);
      await (db.delete(db.items)..where((t) => t.id.equals(loser.id))).go();
      await enqueueSync(
        db,
        collection: 'items',
        docId: loser.id,
        payload: {'_deleted': true},
      );
      removed++;
    }
  }

  // Purge leftover soft-hidden dups with DUP- qr.
  final orphans = await (db.select(db.items)
        ..where((t) => t.qrCode.like('DUP-%') | t.name.like('%(dup)%')))
      .get();
  for (final o in orphans) {
    final keep = rows.where((r) => r.id != o.id && r.isActive).toList();
    if (keep.isNotEmpty) {
      await _remapItemId(db, from: o.id, to: keep.first.id);
    }
    await (db.delete(db.items)..where((t) => t.id.equals(o.id))).go();
    await enqueueSync(
      db,
      collection: 'items',
      docId: o.id,
      payload: {'_deleted': true},
    );
    removed++;
  }
  return removed;
}

Future<int> _dedupeParties(AppDatabase db) async {
  final rows = await db.select(db.parties).get();
  final groups = <String, List<Party>>{};
  for (final r in rows) {
    final raw = r.qrCode.trim();
    if (raw.startsWith('DUP-')) continue;
    final key = raw.isEmpty ? 'id:${r.id}' : raw;
    (groups[key] ??= []).add(r);
  }

  var removed = 0;
  for (final list in groups.values) {
    if (list.length < 2) continue;
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    final keep = list.first;
    if (!keep.isActive) {
      await (db.update(db.parties)..where((t) => t.id.equals(keep.id))).write(
        PartiesCompanion(
          isActive: const Value(true),
          name: Value(keep.name.replaceAll(' (dup)', '')),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
    for (final loser in list.skip(1)) {
      await _remapPartyId(db, from: loser.id, to: keep.id);
      await (db.delete(db.parties)..where((t) => t.id.equals(loser.id))).go();
      await enqueueSync(
        db,
        collection: 'parties',
        docId: loser.id,
        payload: {'_deleted': true},
      );
      removed++;
    }
  }

  final orphans = await (db.select(db.parties)
        ..where((t) => t.qrCode.like('DUP-%') | t.name.like('%(dup)%')))
      .get();
  for (final o in orphans) {
    final keep = rows.where((r) => r.id != o.id && r.isActive).toList();
    if (keep.isNotEmpty) {
      await _remapPartyId(db, from: o.id, to: keep.first.id);
    }
    await (db.delete(db.parties)..where((t) => t.id.equals(o.id))).go();
    await enqueueSync(
      db,
      collection: 'parties',
      docId: o.id,
      payload: {'_deleted': true},
    );
    removed++;
  }
  return removed;
}

Future<void> _remapItemId(
  AppDatabase db, {
  required String from,
  required String to,
}) async {
  if (from == to) return;
  final fromBalances = await (db.select(db.stockBalances)
        ..where((t) => t.itemId.equals(from)))
      .get();
  for (final bal in fromBalances) {
    final existing = await (db.select(db.stockBalances)
          ..where(
            (t) => t.itemId.equals(to) & t.locationId.equals(bal.locationId),
          ))
        .getSingleOrNull();
    if (existing == null) {
      await (db.update(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(from) & t.locationId.equals(bal.locationId),
            ))
          .write(StockBalancesCompanion(itemId: Value(to)));
    } else {
      await (db.update(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(to) & t.locationId.equals(bal.locationId),
            ))
          .write(
        StockBalancesCompanion(
          qty: Value(existing.qty + bal.qty),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await (db.delete(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(from) & t.locationId.equals(bal.locationId),
            ))
          .go();
    }
  }
  await (db.update(db.stockEvents)..where((t) => t.itemId.equals(from)))
      .write(StockEventsCompanion(itemId: Value(to)));
  await (db.update(db.billLines)..where((t) => t.itemId.equals(from)))
      .write(BillLinesCompanion(itemId: Value(to)));
  await (db.update(db.bomRecipes)..where((t) => t.finishedItemId.equals(from)))
      .write(BomRecipesCompanion(finishedItemId: Value(to)));
  await (db.update(db.bomLines)..where((t) => t.ingredientItemId.equals(from)))
      .write(BomLinesCompanion(ingredientItemId: Value(to)));
}

Future<void> _remapPartyId(
  AppDatabase db, {
  required String from,
  required String to,
}) async {
  if (from == to) return;
  await (db.update(db.bills)..where((t) => t.partyId.equals(from)))
      .write(BillsCompanion(partyId: Value(to)));
  await (db.update(db.payments)..where((t) => t.partyId.equals(from)))
      .write(PaymentsCompanion(partyId: Value(to)));

  final loser = await (db.select(db.parties)..where((t) => t.id.equals(from)))
      .getSingleOrNull();
  final keeper = await (db.select(db.parties)..where((t) => t.id.equals(to)))
      .getSingleOrNull();
  if (loser != null && keeper != null) {
    await (db.update(db.parties)..where((t) => t.id.equals(to))).write(
      PartiesCompanion(
        balance: Value(keeper.balance + loser.balance),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
