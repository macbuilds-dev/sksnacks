import 'package:drift/drift.dart';

import '../../data/local/app_database.dart';

DateTime? parseRemoteTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  if (v is int) {
    // ms or seconds
    if (v > 100000000000) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
  }
  if (v is double) return parseRemoteTime(v.toInt());
  if (v is String && v.isNotEmpty) {
    try {
      return DateTime.parse(v).toUtc();
    } catch (_) {
      return null;
    }
  }
  // Firestore Timestamp duck-typing
  try {
    final dyn = v as dynamic;
    final seconds = dyn.seconds as int?;
    final nanos = dyn.nanoseconds as int? ?? 0;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanos ~/ 1000000),
        isUtc: true,
      );
    }
  } catch (_) {}
  return null;
}

DateTime remoteStamp(Map<String, dynamic> data) =>
    parseRemoteTime(data['updatedAt']) ??
    parseRemoteTime(data['at']) ??
    parseRemoteTime(data['createdAt']) ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Wall-clock stamp — Drift often stores UTC instants as "local" DateTimes,
/// so plain toUtc() can shift by TZ and make remote look newer every pull.
int syncStampMs(DateTime? d) {
  if (d == null) return 0;
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
  ).millisecondsSinceEpoch;
}

bool remoteIsNewer(DateTime remote, DateTime? local) {
  if (local == null) return true;
  // Require >2s delta so equal/near-equal stamps are not re-applied forever.
  return syncStampMs(remote) > syncStampMs(local) + 2000;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? fallback;
}

int asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

bool asBool(dynamic v, [bool fallback = true]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '$v'.toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

String? asString(dynamic v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

/// Apply one Firestore doc into Drift. Returns true if local changed.
Future<bool> applyRemoteDoc(
  AppDatabase db, {
  required String collection,
  required String docId,
  required Map<String, dynamic> data,
}) async {
  if (data['_deleted'] == true) {
    return _applyDelete(db, collection, docId);
  }

  switch (collection) {
    case 'items':
      return _applyItem(db, docId, data);
    case 'locations':
      return _applyLocation(db, docId, data);
    case 'parties':
      return _applyParty(db, docId, data);
    case 'bills':
      return _applyBill(db, docId, data);
    case 'payments':
      return _applyPayment(db, docId, data);
    case 'cash_entries':
      return _applyCash(db, docId, data);
    case 'stock_events':
      return _applyStockEvent(db, docId, data);
    case 'stock_balances':
      return _applyStockBalance(db, docId, data);
    case 'bom_recipes':
      return _applyBomRecipe(db, docId, data);
    case 'production_runs':
      return _applyProductionRun(db, docId, data);
    case 'day_checks':
      return _applyDayCheck(db, docId, data);
    case 'owners':
      // Owner presets live in app code; cloud copy is reference-only.
      return false;
    case 'audit_events':
      // Push-only archive (local ids are auto-increment).
      return false;
    default:
      return false;
  }
}

Future<bool> _applyDelete(
  AppDatabase db,
  String collection,
  String docId,
) async {
  switch (collection) {
    case 'cash_entries':
      await (db.delete(db.cashEntries)..where((t) => t.id.equals(docId))).go();
      return true;
    case 'items':
      await (db.update(db.items)..where((t) => t.id.equals(docId))).write(
        ItemsCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return true;
    case 'parties':
      await (db.update(db.parties)..where((t) => t.id.equals(docId))).write(
        PartiesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return true;
    case 'locations':
      await (db.delete(db.locations)..where((t) => t.id.equals(docId))).go();
      return true;
    default:
      return false;
  }
}

Future<bool> _applyItem(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final remoteAt = remoteStamp(data);
  final qr = asString(data['qrCode']) ?? 'SH-$docId';

  var targetId = docId;
  final byId = await (db.select(db.items)..where((t) => t.id.equals(docId)))
      .getSingleOrNull();

  if (byId == null) {
    final byQr = await (db.select(db.items)
          ..where((t) => t.qrCode.equals(qr) & t.isActive.equals(true)))
        .getSingleOrNull();
    if (byQr != null) {
      targetId = byQr.id;
      if (!remoteIsNewer(remoteAt, byQr.updatedAt)) return false;
    }
  } else if (!remoteIsNewer(remoteAt, byId.updatedAt)) {
    return false;
  }

  final created = parseRemoteTime(data['createdAt']) ?? remoteAt;
  await db.into(db.items).insertOnConflictUpdate(
        ItemsCompanion.insert(
          id: targetId,
          qrCode: qr,
          name: asString(data['name']) ?? 'Item',
          nameUr: Value(asString(data['nameUr'])),
          sku: Value(asString(data['sku'])),
          barcode: Value(asString(data['barcode'])),
          category: Value(asString(data['category'])),
          unit: Value(asString(data['unit']) ?? 'pcs'),
          salePrice: Value(asDouble(data['salePrice'])),
          costPrice: Value(asDouble(data['costPrice'])),
          reorderLevel: Value(asDouble(data['reorderLevel'])),
          imagePath: Value(asString(data['imagePath'])),
          notes: Value(asString(data['notes'])),
          isActive: Value(asBool(data['isActive'])),
          createdAt: created,
          updatedAt: remoteAt,
        ),
      );
  return true;
}

Future<bool> _applyLocation(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final remoteAt = remoteStamp(data);
  final kind = asString(data['kind']) ?? 'other';
  final name = asString(data['name']) ?? 'Location';

  var targetId = docId;
  final byId = await (db.select(db.locations)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();

  if (byId == null) {
    // Avoid cloning seed/cloud pairs: reuse existing active row for same kind/name.
    final active = await (db.select(db.locations)
          ..where((t) => t.isActive.equals(true)))
        .get();
    Location? match;
    if (kind != 'other') {
      for (final l in active) {
        if (l.kind == kind) {
          match = l;
          break;
        }
      }
    }
    if (match == null) {
      final nameKey = name.toLowerCase();
      for (final l in active) {
        if (l.name.toLowerCase() == nameKey) {
          match = l;
          break;
        }
      }
    }
    if (match != null) {
      targetId = match.id;
      if (!remoteIsNewer(remoteAt, match.updatedAt)) return false;
    }
  } else if (!remoteIsNewer(remoteAt, byId.updatedAt)) {
    return false;
  }

  final created = parseRemoteTime(data['createdAt']) ?? remoteAt;
  await db.into(db.locations).insertOnConflictUpdate(
        LocationsCompanion.insert(
          id: targetId,
          name: name,
          kind: kind,
          address: Value(asString(data['address'])),
          phone: Value(asString(data['phone'])),
          isActive: Value(asBool(data['isActive'])),
          sortOrder: Value(asInt(data['sortOrder'])),
          createdAt: created,
          updatedAt: remoteAt,
        ),
      );
  return true;
}

Future<bool> _applyParty(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final remoteAt = remoteStamp(data);
  final qr = asString(data['qrCode']) ?? 'PT-$docId';

  var targetId = docId;
  final byId = await (db.select(db.parties)..where((t) => t.id.equals(docId)))
      .getSingleOrNull();

  if (byId == null) {
    final byQr = await (db.select(db.parties)
          ..where((t) => t.qrCode.equals(qr) & t.isActive.equals(true)))
        .getSingleOrNull();
    if (byQr != null) {
      targetId = byQr.id;
      if (!remoteIsNewer(remoteAt, byQr.updatedAt)) return false;
    }
  } else if (!remoteIsNewer(remoteAt, byId.updatedAt)) {
    return false;
  }

  final created = parseRemoteTime(data['createdAt']) ?? remoteAt;
  await db.into(db.parties).insertOnConflictUpdate(
        PartiesCompanion.insert(
          id: targetId,
          qrCode: qr,
          name: asString(data['name']) ?? 'Party',
          role: asString(data['role']) ?? 'customer',
          phone: Value(asString(data['phone'])),
          phone2: Value(asString(data['phone2'])),
          address: Value(asString(data['address'])),
          city: Value(asString(data['city'])),
          creditLimit: Value(asDouble(data['creditLimit'])),
          balance: Value(asDouble(data['balance'])),
          notes: Value(asString(data['notes'])),
          imagePath: Value(asString(data['imagePath'])),
          isActive: Value(asBool(data['isActive'])),
          createdAt: created,
          updatedAt: remoteAt,
        ),
      );
  return true;
}

Future<bool> _applyBill(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final remoteAt = remoteStamp(data);
  final local =
      await (db.select(db.bills)..where((t) => t.id.equals(docId))).getSingleOrNull();
  if (local != null && !remoteIsNewer(remoteAt, local.updatedAt)) return false;

  final created = parseRemoteTime(data['createdAt']) ?? remoteAt;
  await db.into(db.bills).insertOnConflictUpdate(
        BillsCompanion.insert(
          id: docId,
          qrCode: asString(data['qrCode']) ?? 'BL-$docId',
          billNo: Value(asString(data['billNo'])),
          partyId: asString(data['partyId']) ?? '',
          locationId: Value(asString(data['locationId'])),
          kind: Value(asString(data['kind']) ?? 'sale'),
          total: Value(asDouble(data['total'])),
          discount: Value(asDouble(data['discount'])),
          tax: Value(asDouble(data['tax'])),
          paid: Value(asDouble(data['paid'])),
          status: Value(asString(data['status']) ?? 'open'),
          note: Value(asString(data['note'])),
          createdByOwnerId: Value(asString(data['createdByOwnerId'])),
          createdAt: created,
          updatedAt: remoteAt,
        ),
      );

  final lines = data['lines'];
  if (lines is List) {
    await (db.delete(db.billLines)..where((t) => t.billId.equals(docId))).go();
    var i = 0;
    for (final raw in lines) {
      if (raw is! Map) continue;
      final line = Map<String, dynamic>.from(raw);
      final lineId = asString(line['id']) ?? '$docId-L$i';
      await db.into(db.billLines).insertOnConflictUpdate(
            BillLinesCompanion.insert(
              id: lineId,
              billId: docId,
              itemId: Value(asString(line['itemId'])),
              description: asString(line['description']) ?? '',
              qty: asDouble(line['qty'], 1),
              unit: Value(asString(line['unit'])),
              unitPrice: asDouble(line['unitPrice']),
              lineDiscount: Value(asDouble(line['lineDiscount'])),
              lineTotal: Value(asDouble(line['lineTotal'])),
              sortOrder: Value(asInt(line['sortOrder'], i)),
            ),
          );
      i++;
    }
  }
  return true;
}

Future<bool> _applyPayment(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final existing = await (db.select(db.payments)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (existing != null) return false;

  final at = parseRemoteTime(data['at']) ?? DateTime.now().toUtc();
  await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: docId,
          partyId: asString(data['partyId']) ?? '',
          billId: Value(asString(data['billId'])),
          amount: asDouble(data['amount']),
          method: Value(asString(data['method']) ?? 'cash'),
          direction: Value(asString(data['direction']) ?? 'in'),
          reference: Value(asString(data['reference'])),
          note: Value(asString(data['note'])),
          at: at,
          createdByOwnerId: Value(asString(data['createdByOwnerId'])),
          createdAt: parseRemoteTime(data['createdAt']) ?? at,
        ),
      );
  return true;
}

Future<bool> _applyCash(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final existing = await (db.select(db.cashEntries)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (existing != null) return false;

  final at = parseRemoteTime(data['at']) ?? DateTime.now().toUtc();
  await db.into(db.cashEntries).insert(
        CashEntriesCompanion.insert(
          id: docId,
          kind: asString(data['kind']) ?? 'in',
          amount: asDouble(data['amount']),
          source: Value(asString(data['source']) ?? 'cash'),
          category: Value(asString(data['category'])),
          locationId: Value(asString(data['locationId'])),
          refType: Value(asString(data['refType'])),
          refId: Value(asString(data['refId'])),
          note: Value(asString(data['note'])),
          actorOwnerId: Value(asString(data['actorOwnerId'])),
          at: at,
          createdAt: parseRemoteTime(data['createdAt']) ?? at,
        ),
      );
  return true;
}

Future<bool> _applyStockEvent(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final existing = await (db.select(db.stockEvents)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (existing != null) return false;

  final at = parseRemoteTime(data['at']) ?? DateTime.now().toUtc();
  final type = asString(data['type']) ?? 'adjust_in';
  final itemId = asString(data['itemId']);
  final locationId = asString(data['locationId']);
  final qty = asDouble(data['qty']);
  if (itemId == null || locationId == null || qty <= 0) return false;

  await db.into(db.stockEvents).insert(
        StockEventsCompanion.insert(
          id: docId,
          type: type,
          itemId: itemId,
          locationId: locationId,
          toLocationId: Value(asString(data['toLocationId'])),
          qty: qty,
          unitCost: Value(
            data['unitCost'] == null ? null : asDouble(data['unitCost']),
          ),
          refType: Value(asString(data['refType'])),
          refId: Value(asString(data['refId'])),
          actorOwnerId: Value(asString(data['actorOwnerId'])),
          note: Value(asString(data['note'])),
          at: at,
          createdAt: parseRemoteTime(data['createdAt']) ?? at,
        ),
      );
  // Qty comes from stock_balances docs (LWW) — do not double-apply events.
  return true;
}

Future<bool> _applyStockBalance(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  // docId format: itemId__locationId (or fields in payload)
  final itemId = asString(data['itemId']);
  final locationId = asString(data['locationId']);
  if (itemId == null || locationId == null) return false;

  final remoteAt = remoteStamp(data);
  final local = await (db.select(db.stockBalances)
        ..where(
          (t) => t.itemId.equals(itemId) & t.locationId.equals(locationId),
        ))
      .getSingleOrNull();
  if (local != null && !remoteIsNewer(remoteAt, local.updatedAt)) return false;

  await db.into(db.stockBalances).insertOnConflictUpdate(
        StockBalancesCompanion.insert(
          itemId: itemId,
          locationId: locationId,
          qty: Value(asDouble(data['qty'])),
          reservedQty: Value(asDouble(data['reservedQty'])),
          updatedAt: remoteAt,
        ),
      );
  return true;
}

Future<bool> _applyBomRecipe(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final remoteAt = remoteStamp(data);
  final local = await (db.select(db.bomRecipes)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (local != null && !remoteIsNewer(remoteAt, local.updatedAt)) return false;

  final created = parseRemoteTime(data['createdAt']) ?? remoteAt;
  await db.into(db.bomRecipes).insertOnConflictUpdate(
        BomRecipesCompanion.insert(
          id: docId,
          finishedItemId: asString(data['finishedItemId']) ?? '',
          name: asString(data['name']) ?? 'Recipe',
          yieldQty: Value(asDouble(data['yieldQty'], 1)),
          yieldUnit: Value(asString(data['yieldUnit'])),
          notes: Value(asString(data['notes'])),
          isActive: Value(asBool(data['isActive'])),
          createdAt: created,
          updatedAt: remoteAt,
        ),
      );

  final lines = data['lines'];
  if (lines is List) {
    await (db.delete(db.bomLines)..where((t) => t.recipeId.equals(docId))).go();
    var i = 0;
    for (final raw in lines) {
      if (raw is! Map) continue;
      final line = Map<String, dynamic>.from(raw);
      final lineId = asString(line['id']) ?? '$docId-BL$i';
      await db.into(db.bomLines).insertOnConflictUpdate(
            BomLinesCompanion.insert(
              id: lineId,
              recipeId: docId,
              ingredientItemId: asString(line['ingredientItemId']) ?? '',
              qty: asDouble(line['qty'], 1),
              unit: Value(asString(line['unit'])),
              wasteFactor: Value(asDouble(line['wasteFactor'])),
              sortOrder: Value(asInt(line['sortOrder'], i)),
            ),
          );
      i++;
    }
  }
  return true;
}

Future<bool> _applyProductionRun(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final existing = await (db.select(db.productionRuns)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (existing != null) return false;

  final at = parseRemoteTime(data['at']) ?? DateTime.now().toUtc();
  await db.into(db.productionRuns).insert(
        ProductionRunsCompanion.insert(
          id: docId,
          recipeId: asString(data['recipeId']) ?? '',
          factoryLocationId: asString(data['factoryLocationId']) ?? '',
          batches: asDouble(data['batches'], 1),
          finishedQty: asDouble(data['finishedQty']),
          status: Value(asString(data['status']) ?? 'done'),
          note: Value(asString(data['note'])),
          actorOwnerId: Value(asString(data['actorOwnerId'])),
          at: at,
          createdAt: parseRemoteTime(data['createdAt']) ?? at,
        ),
      );
  return true;
}

Future<bool> _applyDayCheck(
  AppDatabase db,
  String docId,
  Map<String, dynamic> data,
) async {
  final existing = await (db.select(db.dayChecks)
        ..where((t) => t.id.equals(docId)))
      .getSingleOrNull();
  if (existing != null) return false;

  final at = parseRemoteTime(data['at']) ?? DateTime.now().toUtc();
  await db.into(db.dayChecks).insert(
        DayChecksCompanion.insert(
          id: docId,
          locationId: asString(data['locationId']) ?? '',
          kind: asString(data['kind']) ?? 'in',
          ownerId: Value(asString(data['ownerId'])),
          cashCount: Value(
            data['cashCount'] == null ? null : asDouble(data['cashCount']),
          ),
          note: Value(asString(data['note'])),
          at: at,
          createdAt: parseRemoteTime(data['createdAt']) ?? at,
        ),
      );
  return true;
}
