import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/tenant.dart';
import '../../data/local/app_database.dart';
import '../../features/auth/auth_state.dart';
import 'sync_apply.dart';
import 'sync_dedupe.dart';

class SyncFlushResult {
  const SyncFlushResult({
    required this.sent,
    required this.failed,
    required this.offline,
    required this.remaining,
    this.pulled = 0,
    this.fetched = 0,
    this.enqueued = 0,
    this.lastError,
  });

  final int sent;
  final int failed;
  final bool offline;
  final int remaining;
  final int pulled;
  final int fetched;
  /// Rows packed into outbox from local DB before push (full mirror).
  final int enqueued;
  final String? lastError;
}

/// Collections sync as root docs: sksnacks_items, sksnacks_bills, …
/// (nested under tenants/sksnacks hid names in Console’s tiny pane).
const kSyncCollections = <String>[
  'locations',
  'items',
  'parties',
  'stock_balances',
  'stock_events',
  'bills',
  'payments',
  'cash_entries',
  'bom_recipes',
  'production_runs',
  'day_checks',
  'owners',
  'audit_events',
];

class SyncWorker {
  SyncWorker(this._db);

  final AppDatabase _db;

  Future<User?> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;
    // Cutover: Google Auth required — do not fall back to anonymous.
    debugPrint('SyncWorker: no Firebase user (Google sign-in required)');
    return null;
  }

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return !(connectivity.contains(ConnectivityResult.none) ||
        connectivity.isEmpty);
  }

  /// Two-way sync: pull (only apply if clearly newer) → push outbox →
  /// one-time (or forced) full local mirror via Firestore batches.
  Future<SyncFlushResult> syncTwoWay({bool forceFullMirror = false}) async {
    if (!await _isOnline()) {
      final remaining = await _db.pendingSyncCount();
      return SyncFlushResult(
        sent: 0,
        failed: 0,
        offline: true,
        remaining: remaining,
      );
    }

    final user = await _ensureSignedIn();
    if (user == null) {
      final remaining = await _db.pendingSyncCount();
      return SyncFlushResult(
        sent: 0,
        failed: remaining > 0 ? remaining : 1,
        offline: false,
        remaining: remaining,
        lastError:
            'PERMISSION_DENIED: Google sign-in required before cloud sync.',
      );
    }
    debugPrint('SyncWorker auth uid=${user.uid} two-way');

    var pulled = 0;
    var fetched = 0;
    String? lastError;
    try {
      final pull = await pullRemote();
      pulled = pull.applied;
      fetched = pull.fetched;
    } catch (e, st) {
      debugPrint('SyncWorker pull failed: $e\n$st');
      lastError = '$e';
    }

    // Collapse seed+cloud clones (different UUIDs, same Factory/item/party).
    try {
      await dedupeLocalBusinessData(_db);
    } catch (e, st) {
      debugPrint('SyncWorker dedupe failed: $e\n$st');
    }

    // Mutation outbox first.
    SyncFlushResult push;
    try {
      push = await flushPending(alreadyAuthed: true, drain: true);
    } catch (e, st) {
      debugPrint('SyncWorker flush failed: $e\n$st');
      lastError = '$e';
      push = SyncFlushResult(
        sent: 0,
        failed: 1,
        offline: false,
        remaining: await _db.pendingSyncCount(),
        lastError: '$e',
      );
    }

    // Full mirror: first run (or force) writes ALL local rows straight to
    // Firestore in batches — does not depend on outbox surviving.
    var mirrorSent = 0;
    var mirrorFailed = 0;
    var enqueued = 0;
    try {
      await _ensureMetaTable();
      final mirrored = await _getMeta('full_mirror_v3');
      if (forceFullMirror || mirrored != 'ok') {
        final mirror = await pushFullMirrorDirect();
        mirrorSent = mirror.sent;
        mirrorFailed = mirror.failed;
        enqueued = mirror.sent;
        if (mirror.failed == 0 && mirror.sent > 0) {
          await _setMeta('full_mirror_v3', 'ok');
        }
        lastError = mirror.lastError ?? lastError;
      } else {
        debugPrint('SyncWorker skip full mirror (already done). Mutations only.');
      }
      // Root meta doc for console (lists collection names + counts).
      await _ensureTenantParentDoc();
    } catch (e, st) {
      debugPrint('SyncWorker mirror failed: $e\n$st');
      lastError = '$e';
      mirrorFailed++;
    }

    final remaining = await _db.pendingSyncCount();
    final result = SyncFlushResult(
      sent: push.sent + mirrorSent,
      failed: push.failed + mirrorFailed,
      offline: false,
      remaining: remaining,
      pulled: pulled,
      fetched: fetched,
      enqueued: enqueued,
      lastError: push.lastError ?? lastError,
    );
    debugPrint(
      'SyncWorker done sent=${result.sent} failed=${result.failed} '
      'fetched=$fetched applied=$pulled remaining=$remaining '
      'err=${result.lastError}',
    );
    return result;
  }

  /// Download cloud docs; apply only when remote is clearly newer / missing.
  Future<({int fetched, int applied})> pullRemote() async {
    await _ensureMetaTable();
    var fetched = 0;
    var applied = 0;
    for (final collection in kSyncCollections) {
      if (collection == 'audit_events') continue;

      final primarySnap =
          await shopCollectionRef(collection).limit(500).get();

      // Prefer nested baithak path; fall back to legacy roots then tenants/.
      final snaps = <QuerySnapshot<Map<String, dynamic>>>[primarySnap];
      if (primarySnap.docs.isEmpty) {
        snaps.add(
          await FirebaseFirestore.instance
              .collection(tenantCollectionLegacyRoot(collection))
              .limit(500)
              .get(),
        );
      }
      if (snaps.every((s) => s.docs.isEmpty)) {
        snaps.add(
          await FirebaseFirestore.instance
              .collection(tenantCollectionLegacyNested(collection))
              .limit(500)
              .get(),
        );
      }

      final seenIds = <String>{};
      for (final snap in snaps) {
        fetched += snap.docs.length;
        for (final doc in snap.docs) {
          if (!seenIds.add(doc.id)) continue;
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data.putIfAbsent('id', () => doc.id);
            final changed = await applyRemoteDoc(
              _db,
              collection: collection,
              docId: doc.id,
              data: data,
            );
            if (changed) applied++;
          } catch (e, st) {
            debugPrint('SyncWorker apply $collection/${doc.id}: $e\n$st');
          }
        }
      }
    }
    await _setMeta('last_pull_at', DateTime.now().toUtc().toIso8601String());
    debugPrint(
      'SyncWorker pull fetched=$fetched applied=$applied '
      'skipped=${fetched - applied}',
    );
    return (fetched: fetched, applied: applied);
  }

  /// Write every local business row to Firestore in WriteBatches (max ~400).
  Future<SyncFlushResult> pushFullMirrorDirect() async {
    final docs = <({String collection, String docId, Map<String, dynamic> data})>[];

    void add(String collection, String docId, Map<String, dynamic> data) {
      final clean = Map<String, dynamic>.from(data);
      clean['id'] = docId;
      clean.remove('imagePath');
      clean.putIfAbsent(
        'updatedAt',
        () => DateTime.now().toUtc().toIso8601String(),
      );
      docs.add((collection: collection, docId: docId, data: clean));
    }

    for (final o in ownerPresets) {
      add('owners', o.ownerId, {
        'ownerId': o.ownerId,
        'displayName': o.displayName,
      });
    }

    for (final loc in await _db.select(_db.locations).get()) {
      add('locations', loc.id, {
        'name': loc.name,
        'kind': loc.kind,
        'address': loc.address,
        'phone': loc.phone,
        'isActive': loc.isActive,
        'sortOrder': loc.sortOrder,
        'createdAt': loc.createdAt.toUtc().toIso8601String(),
        'updatedAt': loc.updatedAt.toUtc().toIso8601String(),
      });
    }

    for (final item in await _db.select(_db.items).get()) {
      add('items', item.id, {
        'qrCode': item.qrCode,
        'name': item.name,
        'nameUr': item.nameUr,
        'sku': item.sku,
        'barcode': item.barcode,
        'category': item.category,
        'unit': item.unit,
        'salePrice': item.salePrice,
        'costPrice': item.costPrice,
        'reorderLevel': item.reorderLevel,
        'notes': item.notes,
        'isActive': item.isActive,
        'createdAt': item.createdAt.toUtc().toIso8601String(),
        'updatedAt': item.updatedAt.toUtc().toIso8601String(),
      });
    }

    for (final p in await _db.select(_db.parties).get()) {
      add('parties', p.id, {
        'qrCode': p.qrCode,
        'name': p.name,
        'role': p.role,
        'phone': p.phone,
        'phone2': p.phone2,
        'address': p.address,
        'city': p.city,
        'creditLimit': p.creditLimit,
        'balance': p.balance,
        'notes': p.notes,
        'isActive': p.isActive,
        'createdAt': p.createdAt.toUtc().toIso8601String(),
        'updatedAt': p.updatedAt.toUtc().toIso8601String(),
      });
    }

    for (final b in await _db.select(_db.stockBalances).get()) {
      add('stock_balances', '${b.itemId}__${b.locationId}', {
        'itemId': b.itemId,
        'locationId': b.locationId,
        'qty': b.qty,
        'reservedQty': b.reservedQty,
        'updatedAt': b.updatedAt.toUtc().toIso8601String(),
      });
    }

    for (final e in await _db.select(_db.stockEvents).get()) {
      add('stock_events', e.id, {
        'type': e.type,
        'itemId': e.itemId,
        'locationId': e.locationId,
        'toLocationId': e.toLocationId,
        'qty': e.qty,
        'unitCost': e.unitCost,
        'refType': e.refType,
        'refId': e.refId,
        'actorOwnerId': e.actorOwnerId,
        'note': e.note,
        'at': e.at.toUtc().toIso8601String(),
        'createdAt': e.createdAt.toUtc().toIso8601String(),
        'updatedAt': e.at.toUtc().toIso8601String(),
      });
    }

    for (final bill in await _db.select(_db.bills).get()) {
      final lines = await (_db.select(_db.billLines)
            ..where((t) => t.billId.equals(bill.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      add('bills', bill.id, {
        'qrCode': bill.qrCode,
        'billNo': bill.billNo,
        'partyId': bill.partyId,
        'locationId': bill.locationId,
        'kind': bill.kind,
        'total': bill.total,
        'discount': bill.discount,
        'tax': bill.tax,
        'paid': bill.paid,
        'status': bill.status,
        'note': bill.note,
        'createdByOwnerId': bill.createdByOwnerId,
        'createdAt': bill.createdAt.toUtc().toIso8601String(),
        'updatedAt': bill.updatedAt.toUtc().toIso8601String(),
        'lines': [
          for (final line in lines)
            {
              'id': line.id,
              'itemId': line.itemId,
              'description': line.description,
              'qty': line.qty,
              'unit': line.unit,
              'unitPrice': line.unitPrice,
              'lineDiscount': line.lineDiscount,
              'lineTotal': line.lineTotal,
              'sortOrder': line.sortOrder,
            },
        ],
      });
    }

    for (final pay in await _db.select(_db.payments).get()) {
      add('payments', pay.id, {
        'partyId': pay.partyId,
        'billId': pay.billId,
        'amount': pay.amount,
        'method': pay.method,
        'direction': pay.direction,
        'reference': pay.reference,
        'note': pay.note,
        'at': pay.at.toUtc().toIso8601String(),
        'createdByOwnerId': pay.createdByOwnerId,
        'createdAt': pay.createdAt.toUtc().toIso8601String(),
        'updatedAt': pay.at.toUtc().toIso8601String(),
      });
    }

    for (final c in await _db.select(_db.cashEntries).get()) {
      add('cash_entries', c.id, {
        'kind': c.kind,
        'amount': c.amount,
        'source': c.source,
        'category': c.category,
        'locationId': c.locationId,
        'refType': c.refType,
        'refId': c.refId,
        'note': c.note,
        'actorOwnerId': c.actorOwnerId,
        'at': c.at.toUtc().toIso8601String(),
        'createdAt': c.createdAt.toUtc().toIso8601String(),
        'updatedAt': c.at.toUtc().toIso8601String(),
      });
    }

    for (final d in await _db.select(_db.dayChecks).get()) {
      add('day_checks', d.id, {
        'locationId': d.locationId,
        'kind': d.kind,
        'ownerId': d.ownerId,
        'cashCount': d.cashCount,
        'note': d.note,
        'at': d.at.toUtc().toIso8601String(),
        'createdAt': d.createdAt.toUtc().toIso8601String(),
        'updatedAt': d.at.toUtc().toIso8601String(),
      });
    }

    for (final recipe in await _db.select(_db.bomRecipes).get()) {
      final lines = await (_db.select(_db.bomLines)
            ..where((t) => t.recipeId.equals(recipe.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      add('bom_recipes', recipe.id, {
        'finishedItemId': recipe.finishedItemId,
        'name': recipe.name,
        'yieldQty': recipe.yieldQty,
        'yieldUnit': recipe.yieldUnit,
        'notes': recipe.notes,
        'isActive': recipe.isActive,
        'createdAt': recipe.createdAt.toUtc().toIso8601String(),
        'updatedAt': recipe.updatedAt.toUtc().toIso8601String(),
        'lines': [
          for (final line in lines)
            {
              'id': line.id,
              'ingredientItemId': line.ingredientItemId,
              'qty': line.qty,
              'unit': line.unit,
              'wasteFactor': line.wasteFactor,
              'sortOrder': line.sortOrder,
            },
        ],
      });
    }

    for (final run in await _db.select(_db.productionRuns).get()) {
      add('production_runs', run.id, {
        'recipeId': run.recipeId,
        'factoryLocationId': run.factoryLocationId,
        'batches': run.batches,
        'finishedQty': run.finishedQty,
        'status': run.status,
        'note': run.note,
        'actorOwnerId': run.actorOwnerId,
        'at': run.at.toUtc().toIso8601String(),
        'createdAt': run.createdAt.toUtc().toIso8601String(),
        'updatedAt': run.at.toUtc().toIso8601String(),
      });
    }

    for (final a in await _db.select(_db.auditEvents).get()) {
      add('audit_events', 'aud_${a.id}', {
        'localId': a.id,
        'action': a.action,
        'entity': a.entity,
        'entityId': a.entityId,
        'screen': a.screen,
        'actorOwnerId': a.actorOwnerId,
        'metaJson': a.metaJson,
        'at': a.at.toUtc().toIso8601String(),
        'updatedAt': a.at.toUtc().toIso8601String(),
      });
    }

    debugPrint('SyncWorker mirror preparing ${docs.length} docs → Firestore');
    if (docs.isEmpty) {
      return const SyncFlushResult(
        sent: 0,
        failed: 0,
        offline: false,
        remaining: 0,
      );
    }

    final totals = <String, int>{};
    for (final d in docs) {
      totals[d.collection] = (totals[d.collection] ?? 0) + 1;
    }

    var sent = 0;
    var failed = 0;
    String? lastError;
    const chunk = 400;
    for (var i = 0; i < docs.length; i += chunk) {
      final slice = docs.sublist(i, (i + chunk).clamp(0, docs.length));
      final batch = FirebaseFirestore.instance.batch();
      for (final d in slice) {
        final ref = shopCollectionRef(d.collection)
            .doc(d.docId);
        batch.set(ref, d.data, SetOptions(merge: true));
      }
      try {
        await batch.commit();
        sent += slice.length;
        final byCol = <String, int>{};
        for (final d in slice) {
          byCol[d.collection] = (byCol[d.collection] ?? 0) + 1;
        }
        debugPrint('SyncWorker mirror batch ok +${slice.length} $byCol');
      } catch (e, st) {
        debugPrint('SyncWorker mirror batch FAIL: $e\n$st');
        lastError = '$e';
        // Fall back to per-doc so one bad payload doesn't block the rest.
        for (final d in slice) {
          try {
            await shopCollectionRef(d.collection)
                .doc(d.docId)
                .set(d.data, SetOptions(merge: true));
            sent++;
          } catch (e2, st2) {
            failed++;
            lastError = '$e2';
            debugPrint(
              'SyncWorker mirror doc FAIL ${d.collection}/${d.docId}: $e2\n$st2',
            );
          }
        }
      }
    }

    if (failed == 0 && sent > 0) {
      await _writeTenantIndex(docCounts: totals);
    }

    debugPrint('SyncWorker mirror done sent=$sent failed=$failed');
    return SyncFlushResult(
      sent: sent,
      failed: failed,
      offline: false,
      remaining: await _db.pendingSyncCount(),
      lastError: lastError,
    );
  }

  /// Root meta doc: open `sksnacks_meta` → `index` in Console.
  Future<void> _writeTenantIndex({required Map<String, int> docCounts}) async {
    try {
      final named = <String, int>{
        for (final e in docCounts.entries)
          tenantCollection(e.key): e.value,
      };
      await FirebaseFirestore.instance.doc(tenantMetaDocPath).set(
        {
          'brandId': kBrandId,
          'layout': 'root_collections',
          'exists': true,
          'lastMirrorAt': DateTime.now().toUtc().toIso8601String(),
          'docCounts': named,
          'collections': [
            for (final c in kSyncCollections) tenantCollection(c),
          ],
          'note': 'SHSnacks cloud index',
        },
        SetOptions(merge: true),
      );
      debugPrint('SyncWorker wrote $tenantMetaDocPath index $named');
    } catch (e, st) {
      debugPrint('SyncWorker tenant index write failed: $e\n$st');
    }
  }

  Future<void> _ensureTenantParentDoc() async {
    try {
      await FirebaseFirestore.instance.doc(tenantMetaDocPath).set(
        {
          'brandId': kBrandId,
          'layout': 'root_collections',
          'exists': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'collections': [
            for (final c in kSyncCollections) tenantCollection(c),
          ],
        },
        SetOptions(merge: true),
      );
      debugPrint('SyncWorker ensured $tenantMetaDocPath');
    } catch (e, st) {
      debugPrint('SyncWorker ensure meta failed: $e\n$st');
    }
  }

  Future<SyncFlushResult> flushPending({
    bool alreadyAuthed = false,
    bool drain = false,
  }) async {
    if (!alreadyAuthed) {
      if (!await _isOnline()) {
        final remaining = await _db.pendingSyncCount();
        return SyncFlushResult(
          sent: 0,
          failed: 0,
          offline: true,
          remaining: remaining,
        );
      }
      final user = await _ensureSignedIn();
      if (user == null) {
        final remaining = await _db.pendingSyncCount();
        return SyncFlushResult(
          sent: 0,
          failed: remaining > 0 ? remaining : 1,
          offline: false,
          remaining: remaining,
          lastError:
              'PERMISSION_DENIED: Firebase Anonymous Auth off or sign-in failed.',
        );
      }
    }

    var sentTotal = 0;
    var failedTotal = 0;
    String? lastError;
    var rounds = 0;
    const maxRounds = 25;

    do {
      rounds++;
      final batch = await _flushOneBatch();
      sentTotal += batch.sent;
      failedTotal += batch.failed;
      lastError = batch.lastError ?? lastError;
      if (!drain) break;
      if (batch.sent == 0 && batch.failed == 0) break;
      if (batch.sent == 0 && batch.failed > 0) break;
      if (batch.remaining == 0) break;
    } while (rounds < maxRounds);

    debugPrint(
      'SyncWorker outbox flush sent=$sentTotal failed=$failedTotal '
      'rounds=$rounds',
    );
    return SyncFlushResult(
      sent: sentTotal,
      failed: failedTotal,
      offline: false,
      remaining: await _db.pendingSyncCount(),
      lastError: lastError,
    );
  }

  Future<SyncFlushResult> _flushOneBatch() async {
    await (_db.update(_db.syncOutbox)
          ..where((t) => t.status.equals('failed')))
        .write(
      SyncOutboxCompanion(
        status: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final pending = await (_db.select(_db.syncOutbox)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(400))
        .get();

    if (pending.isEmpty) {
      return SyncFlushResult(
        sent: 0,
        failed: 0,
        offline: false,
        remaining: await _db.pendingSyncCount(),
      );
    }

    final latestByKey = <String, SyncOutboxData>{};
    for (final row in pending) {
      latestByKey['${row.collection}|${row.docId}'] = row;
    }
    final toSend = latestByKey.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Prefer a single Firestore batch for speed/reliability.
    final fsBatch = FirebaseFirestore.instance.batch();
    final prepared = <SyncOutboxData>[];
    final now = DateTime.now();
    for (final row in toSend) {
      try {
        final data = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        data['id'] = row.docId;
        data.remove('imagePath');
        data.putIfAbsent('updatedAt', () => now.toUtc().toIso8601String());
        final ref = shopCollectionRef(row.collection)
            .doc(row.docId);
        fsBatch.set(ref, data, SetOptions(merge: true));
        prepared.add(row);
      } catch (e, st) {
        debugPrint('SyncWorker outbox prepare FAIL ${row.docId}: $e\n$st');
        await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(row.id)))
            .write(
          SyncOutboxCompanion(
            status: const Value('failed'),
            attempts: Value(row.attempts + 1),
            lastError: Value('$e'),
            updatedAt: Value(now),
          ),
        );
      }
    }

    if (prepared.isEmpty) {
      return SyncFlushResult(
        sent: 0,
        failed: toSend.length,
        offline: false,
        remaining: await _db.pendingSyncCount(),
        lastError: 'outbox prepare failed',
      );
    }

    try {
      await fsBatch.commit();
      for (final row in prepared) {
        await (_db.update(_db.syncOutbox)
              ..where(
                (t) =>
                    t.collection.equals(row.collection) &
                    t.docId.equals(row.docId) &
                    t.status.equals('pending'),
              ))
            .write(
          SyncOutboxCompanion(
            status: const Value('sent'),
            updatedAt: Value(now),
            lastError: const Value(null),
          ),
        );
      }
      return SyncFlushResult(
        sent: prepared.length,
        failed: 0,
        offline: false,
        remaining: await _db.pendingSyncCount(),
      );
    } catch (e, st) {
      debugPrint('SyncWorker outbox batch FAIL, per-doc fallback: $e\n$st');
      var sent = 0;
      var failed = 0;
      String? lastError = '$e';
      for (final row in prepared) {
        try {
          final data = jsonDecode(row.payloadJson) as Map<String, dynamic>;
          data['id'] = row.docId;
          data.remove('imagePath');
          await shopCollectionRef(row.collection)
              .doc(row.docId)
              .set(data, SetOptions(merge: true));
          await (_db.update(_db.syncOutbox)
                ..where(
                  (t) =>
                      t.collection.equals(row.collection) &
                      t.docId.equals(row.docId) &
                      t.status.equals('pending'),
                ))
              .write(
            SyncOutboxCompanion(
              status: const Value('sent'),
              updatedAt: Value(now),
              lastError: const Value(null),
            ),
          );
          sent++;
        } catch (e2, st2) {
          failed++;
          lastError = '$e2';
          debugPrint('SyncWorker outbox doc FAIL ${row.docId}: $e2\n$st2');
          await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(row.id)))
              .write(
            SyncOutboxCompanion(
              status: const Value('failed'),
              attempts: Value(row.attempts + 1),
              lastError: Value('$e2'),
              updatedAt: Value(now),
            ),
          );
        }
      }
      return SyncFlushResult(
        sent: sent,
        failed: failed,
        offline: false,
        remaining: await _db.pendingSyncCount(),
        lastError: lastError,
      );
    }
  }

  Future<void> _ensureMetaTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _setMeta(String key, String value) async {
    await _ensureMetaTable();
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT OR REPLACE INTO sync_meta (key, value, updated_at) VALUES (?, ?, ?)',
      [key, value, ms],
    );
  }

  Future<String?> _getMeta(String key) async {
    await _ensureMetaTable();
    final rows = await _db.customSelect(
      'SELECT value FROM sync_meta WHERE key = ?',
      variables: [Variable.withString(key)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('value');
  }

  /// Clears the one-time mirror flag so next sync uploads everything again.
  Future<void> resetFullMirrorFlag() async {
    await _ensureMetaTable();
    await _db.customStatement(
      "DELETE FROM sync_meta WHERE key IN ('full_mirror_v2', 'full_mirror_v3')",
    );
  }
}

Future<void> enqueueSync(
  AppDatabase db, {
  required String collection,
  required String docId,
  required Map<String, dynamic> payload,
}) async {
  final now = DateTime.now();
  final enriched = Map<String, dynamic>.from(payload);
  enriched.putIfAbsent('id', () => docId);
  enriched.putIfAbsent('updatedAt', () => now.toUtc().toIso8601String());
  enriched.remove('imagePath');
  await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          collection: collection,
          docId: docId,
          payloadJson: jsonEncode(enriched),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> writeAudit(
  AppDatabase db, {
  required String action,
  String? entity,
  String? entityId,
  String? screen,
  String? actorOwnerId,
  Map<String, dynamic>? meta,
}) async {
  final at = DateTime.now();
  final rowId = await db.into(db.auditEvents).insert(
        AuditEventsCompanion.insert(
          action: action,
          entity: Value(entity),
          entityId: Value(entityId),
          screen: Value(screen),
          actorOwnerId: Value(actorOwnerId),
          metaJson: Value(meta == null ? null : jsonEncode(meta)),
          at: at,
        ),
      );
  await enqueueSync(
    db,
    collection: 'audit_events',
    docId: 'aud_$rowId',
    payload: {
      'localId': rowId,
      'action': action,
      'entity': entity,
      'entityId': entityId,
      'screen': screen,
      'actorOwnerId': actorOwnerId,
      'metaJson': meta == null ? null : jsonEncode(meta),
      'at': at.toUtc().toIso8601String(),
    },
  );
}
