import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/sync_worker.dart';
import '../../l10n/app_copy.dart';
import '../local/app_database.dart';

const _uuid = Uuid();

String _newQrCode([String prefix = 'SH']) =>
    '$prefix-${_uuid.v4().substring(0, 8).toUpperCase()}';

Map<String, dynamic> _itemPayload(Item i) => {
      'id': i.id,
      'qrCode': i.qrCode,
      'name': i.name,
      'nameUr': i.nameUr,
      'sku': i.sku,
      'barcode': i.barcode,
      'category': i.category,
      'unit': i.unit,
      'salePrice': i.salePrice,
      'costPrice': i.costPrice,
      'reorderLevel': i.reorderLevel,
      'imagePath': i.imagePath,
      'notes': i.notes,
      'isActive': i.isActive,
      'createdAt': i.createdAt.toIso8601String(),
      'updatedAt': i.updatedAt.toIso8601String(),
    };

class InventoryRepository {
  InventoryRepository(this.db);
  final AppDatabase db;

  Stream<List<Item>> watchItems({bool activeOnly = true}) {
    final q = db.select(db.items)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (activeOnly) {
      q.where((t) => t.isActive.equals(true));
    }
    return q.watch();
  }

  Stream<List<Location>> watchLocations({bool activeOnly = true}) {
    final q = db.select(db.locations)
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
      ]);
    if (activeOnly) q.where((t) => t.isActive.equals(true));
    return q.watch();
  }

  Future<Item?> itemById(String id) =>
      (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Item?> itemByQrCode(String qrCode) => (db.select(db.items)
        ..where((t) => t.qrCode.equals(qrCode) & t.isActive.equals(true)))
      .getSingleOrNull();

  /// Resolves scan payload to item (SK-… or legacy id).
  Future<Item?> resolveItemQr(String raw) async {
    final byCode = await itemByQrCode(raw);
    if (byCode != null) return byCode;
    return itemById(raw);
  }

  Future<Location?> locationById(String id) => (db.select(db.locations)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  Future<double> qtyAt({required String itemId, required String locationId}) async {
    final row = await (db.select(db.stockBalances)
          ..where((t) =>
              t.itemId.equals(itemId) & t.locationId.equals(locationId)))
        .getSingleOrNull();
    return row?.qty ?? 0;
  }

  Future<Map<String, double>> totalsByItem() async {
    final rows = await db.select(db.stockBalances).get();
    final map = <String, double>{};
    for (final r in rows) {
      map[r.itemId] = (map[r.itemId] ?? 0) + r.qty;
    }
    return map;
  }

  Future<String> addItem({
    required String name,
    String? nameUr,
    String? sku,
    String? barcode,
    String? category,
    String unit = 'pcs',
    double salePrice = 0,
    double costPrice = 0,
    double reorderLevel = 0,
    String? notes,
    String? imagePath,
    String? qrCode,
    String? actorOwnerId,
  }) async {
    final id = _uuid.v4();
    final code = (qrCode == null || qrCode.trim().isEmpty)
        ? _newQrCode()
        : qrCode.trim();
    final now = DateTime.now();
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: id,
            qrCode: code,
            name: name,
            nameUr: Value(nameUr),
            sku: Value(sku),
            barcode: Value(barcode),
            category: Value(category),
            unit: Value(unit),
            salePrice: Value(salePrice),
            costPrice: Value(costPrice),
            reorderLevel: Value(reorderLevel),
            imagePath: Value(imagePath),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final item = (await itemById(id))!;
    await enqueueSync(
      db,
      collection: 'items',
      docId: id,
      payload: _itemPayload(item),
    );
    await writeAudit(
      db,
      action: 'create',
      entity: 'items',
      entityId: id,
      screen: 'inventory',
      actorOwnerId: actorOwnerId,
    );
    return id;
  }

  Future<void> updateItem({
    required String id,
    String? name,
    String? nameUr,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? salePrice,
    double? costPrice,
    double? reorderLevel,
    String? notes,
    String? imagePath,
    bool clearImage = false,
    String? qrCode,
    bool? isActive,
    String? actorOwnerId,
  }) async {
    final now = DateTime.now();
    await (db.update(db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        nameUr: nameUr == null ? const Value.absent() : Value(nameUr),
        sku: sku == null ? const Value.absent() : Value(sku),
        barcode: barcode == null ? const Value.absent() : Value(barcode),
        category: category == null ? const Value.absent() : Value(category),
        unit: unit == null ? const Value.absent() : Value(unit),
        salePrice: salePrice == null ? const Value.absent() : Value(salePrice),
        costPrice: costPrice == null ? const Value.absent() : Value(costPrice),
        reorderLevel:
            reorderLevel == null ? const Value.absent() : Value(reorderLevel),
        notes: notes == null ? const Value.absent() : Value(notes),
        imagePath: clearImage
            ? const Value(null)
            : imagePath == null
                ? const Value.absent()
                : Value(imagePath),
        qrCode: qrCode == null ? const Value.absent() : Value(qrCode),
        isActive: isActive == null ? const Value.absent() : Value(isActive),
        updatedAt: Value(now),
      ),
    );
    final item = await itemById(id);
    if (item != null) {
      await enqueueSync(
        db,
        collection: 'items',
        docId: id,
        payload: _itemPayload(item),
      );
    }
    await writeAudit(
      db,
      action: 'update',
      entity: 'items',
      entityId: id,
      screen: 'inventory',
      actorOwnerId: actorOwnerId,
    );
  }

  Future<void> softDeleteItem(String id, {String? actorOwnerId}) async {
    await updateItem(id: id, isActive: false, actorOwnerId: actorOwnerId);
  }

  Future<String> addLocation({
    required String name,
    required String kind,
    String? address,
    String? phone,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.locations).insert(
          LocationsCompanion.insert(
            id: id,
            name: name,
            kind: kind,
            address: Value(address),
            phone: Value(phone),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await enqueueSync(
      db,
      collection: 'locations',
      docId: id,
      payload: {
        'name': name,
        'kind': kind,
        'address': address,
        'phone': phone,
        'sortOrder': sortOrder,
        'isActive': true,
        'updatedAt': now.toIso8601String(),
      },
    );
    return id;
  }

  Future<void> updateLocation({
    required String id,
    String? name,
    String? kind,
    String? address,
    String? phone,
    bool? isActive,
    int? sortOrder,
  }) async {
    final now = DateTime.now();
    await (db.update(db.locations)..where((t) => t.id.equals(id))).write(
      LocationsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        kind: kind == null ? const Value.absent() : Value(kind),
        address: address == null ? const Value.absent() : Value(address),
        phone: phone == null ? const Value.absent() : Value(phone),
        isActive: isActive == null ? const Value.absent() : Value(isActive),
        sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
        updatedAt: Value(now),
      ),
    );
    final loc = await locationById(id);
    if (loc != null) {
      await enqueueSync(
        db,
        collection: 'locations',
        docId: id,
        payload: {
          'name': loc.name,
          'kind': loc.kind,
          'address': loc.address,
          'phone': loc.phone,
          'isActive': loc.isActive,
          'sortOrder': loc.sortOrder,
          'updatedAt': now.toIso8601String(),
        },
      );
    }
  }

  /// Hard-delete a location after remapping stock/bills to another place.
  Future<void> deleteLocation(String id) async {
    final loc = await locationById(id);
    if (loc == null) return;

    final others = await (db.select(db.locations)
          ..where((t) => t.isActive.equals(true) & t.id.equals(id).not()))
        .get();
    if (others.isEmpty) {
      throw StateError(Copy.locDeleteNeedOne);
    }
    final to = others.first.id;

    // Remap FKs (same logic as sync dedupe).
    final fromBalances = await (db.select(db.stockBalances)
          ..where((t) => t.locationId.equals(id)))
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
                    t.itemId.equals(bal.itemId) & t.locationId.equals(id),
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
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (db.delete(db.stockBalances)
              ..where(
                (t) =>
                    t.itemId.equals(bal.itemId) & t.locationId.equals(id),
              ))
            .go();
      }
    }
    await (db.update(db.stockEvents)..where((t) => t.locationId.equals(id)))
        .write(StockEventsCompanion(locationId: Value(to)));
    await (db.update(db.stockEvents)..where((t) => t.toLocationId.equals(id)))
        .write(StockEventsCompanion(toLocationId: Value(to)));
    await (db.update(db.bills)..where((t) => t.locationId.equals(id)))
        .write(BillsCompanion(locationId: Value(to)));
    await (db.update(db.cashEntries)..where((t) => t.locationId.equals(id)))
        .write(CashEntriesCompanion(locationId: Value(to)));
    await (db.update(db.dayChecks)..where((t) => t.locationId.equals(id)))
        .write(DayChecksCompanion(locationId: Value(to)));
    await (db.update(db.productionRuns)
          ..where((t) => t.factoryLocationId.equals(id)))
        .write(ProductionRunsCompanion(factoryLocationId: Value(to)));

    await (db.delete(db.locations)..where((t) => t.id.equals(id))).go();
    await enqueueSync(
      db,
      collection: 'locations',
      docId: id,
      payload: {'_deleted': true},
    );
  }

  Future<void> _setBalance({
    required String itemId,
    required String locationId,
    required double qty,
  }) async {
    final now = DateTime.now();
    await db.into(db.stockBalances).insertOnConflictUpdate(
          StockBalancesCompanion.insert(
            itemId: itemId,
            locationId: locationId,
            qty: Value(qty),
            updatedAt: now,
          ),
        );
  }

  Future<void> applyStockEvent({
    required String type,
    required String itemId,
    required String locationId,
    required double qty,
    String? toLocationId,
    String? note,
    double? unitCost,
    String? refType,
    String? refId,
    String? actorOwnerId,
  }) async {
    if (qty <= 0) throw ArgumentError('Qty must be > 0');
    final id = _uuid.v4();
    final now = DateTime.now();

    if (type == 'transfer') {
      final from = await qtyAt(itemId: itemId, locationId: locationId);
      if (from < qty) throw StateError('Itna maal nahi hai is jagah');
      final toId = toLocationId!;
      final to = await qtyAt(itemId: itemId, locationId: toId);
      await _setBalance(itemId: itemId, locationId: locationId, qty: from - qty);
      await _setBalance(itemId: itemId, locationId: toId, qty: to + qty);
      await db.into(db.stockEvents).insert(
            StockEventsCompanion.insert(
              id: id,
              type: 'transfer',
              itemId: itemId,
              locationId: locationId,
              toLocationId: Value(toId),
              qty: qty,
              unitCost: Value(unitCost),
              refType: Value(refType),
              refId: Value(refId),
              actorOwnerId: Value(actorOwnerId),
              note: Value(note),
              at: now,
              createdAt: now,
            ),
          );
    } else {
      final current = await qtyAt(itemId: itemId, locationId: locationId);
      late double next;
      switch (type) {
        case 'purchase':
        case 'produce':
        case 'adjust_in':
        case 'return':
          next = current + qty;
        case 'sale':
        case 'waste':
        case 'adjust_out':
          if (current < qty) throw StateError('Stock kam hai');
          next = current - qty;
        default:
          throw ArgumentError('Unknown type $type');
      }
      await _setBalance(itemId: itemId, locationId: locationId, qty: next);
      await db.into(db.stockEvents).insert(
            StockEventsCompanion.insert(
              id: id,
              type: type,
              itemId: itemId,
              locationId: locationId,
              qty: qty,
              unitCost: Value(unitCost),
              refType: Value(refType),
              refId: Value(refId),
              actorOwnerId: Value(actorOwnerId),
              note: Value(note),
              at: now,
              createdAt: now,
            ),
          );
    }

    await enqueueSync(
      db,
      collection: 'stock_events',
      docId: id,
      payload: {
        'type': type,
        'itemId': itemId,
        'locationId': locationId,
        'toLocationId': toLocationId,
        'qty': qty,
        'unitCost': unitCost,
        'refType': refType,
        'refId': refId,
        'actorOwnerId': actorOwnerId,
        'note': note,
        'at': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
    );

    // Push balance snapshot so other devices get spinal-cord qty without replay gaps.
    Future<void> enqueueBalance(String item, String loc) async {
      final q = await qtyAt(itemId: item, locationId: loc);
      await enqueueSync(
        db,
        collection: 'stock_balances',
        docId: '${item}__$loc',
        payload: {
          'itemId': item,
          'locationId': loc,
          'qty': q,
          'updatedAt': now.toIso8601String(),
        },
      );
    }

    await enqueueBalance(itemId, locationId);
    if (type == 'transfer' && toLocationId != null) {
      await enqueueBalance(itemId, toLocationId);
    }
  }

  Future<Map<String, double>> qtyByLocation(String itemId) async {
    final rows = await (db.select(db.stockBalances)
          ..where((t) => t.itemId.equals(itemId)))
        .get();
    return {for (final r in rows) r.locationId: r.qty};
  }

  Stream<List<StockEvent>> watchEventsForItem(String itemId) =>
      (db.select(db.stockEvents)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.at)])
            ..limit(40))
          .watch();

  /// Bill lines for this item with party + bill meta (sales / purchases).
  Future<List<({Bill bill, Party? party, BillLine line})>> partyLinksForItem(
    String itemId,
  ) async {
    final lines = await (db.select(db.billLines)
          ..where((t) => t.itemId.equals(itemId)))
        .get();
    final out = <({Bill bill, Party? party, BillLine line})>[];
    for (final line in lines) {
      final bill = await (db.select(db.bills)
            ..where((t) => t.id.equals(line.billId)))
          .getSingleOrNull();
      if (bill == null) continue;
      final party = await (db.select(db.parties)
            ..where((t) => t.id.equals(bill.partyId)))
          .getSingleOrNull();
      out.add((bill: bill, party: party, line: line));
    }
    out.sort((a, b) => b.bill.createdAt.compareTo(a.bill.createdAt));
    return out;
  }
}

class CashRepository {
  CashRepository(this.db);
  final AppDatabase db;

  Stream<List<CashEntry>> watchEntries() => (db.select(db.cashEntries)
        ..orderBy([(t) => OrderingTerm.desc(t.at)]))
      .watch();

  Future<CashEntry?> byId(String id) => (db.select(db.cashEntries)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  Future<String> add({
    required String kind,
    required double amount,
    String source = 'cash',
    String? category,
    String? locationId,
    String? note,
    String? actorOwnerId,
    String? refType,
    String? refId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.cashEntries).insert(
          CashEntriesCompanion.insert(
            id: id,
            kind: kind,
            amount: amount,
            source: Value(source),
            category: Value(category),
            locationId: Value(locationId),
            refType: Value(refType),
            refId: Value(refId),
            note: Value(note),
            actorOwnerId: Value(actorOwnerId),
            at: now,
            createdAt: now,
          ),
        );
    await enqueueSync(
      db,
      collection: 'cash_entries',
      docId: id,
      payload: {
        'kind': kind,
        'amount': amount,
        'source': source,
        'category': category,
        'locationId': locationId,
        'note': note,
        'actorOwnerId': actorOwnerId,
        'at': now.toIso8601String(),
      },
    );
    return id;
  }

  Future<void> delete(String id) async {
    await (db.delete(db.cashEntries)..where((t) => t.id.equals(id))).go();
    await enqueueSync(
      db,
      collection: 'cash_entries',
      docId: id,
      payload: {'_deleted': true},
    );
  }
}

class KhataRepository {
  KhataRepository(this.db);
  final AppDatabase db;

  Stream<List<Party>> watchParties({bool activeOnly = true}) {
    final q = db.select(db.parties)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (activeOnly) q.where((t) => t.isActive.equals(true));
    return q.watch();
  }

  Stream<List<Bill>> watchBills() => (db.select(db.bills)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<Party?> partyById(String id) =>
      (db.select(db.parties)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Bill?> billById(String id) =>
      (db.select(db.bills)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> addParty({
    required String name,
    required String role,
    String? phone,
    String? phone2,
    String? address,
    String? city,
    double creditLimit = 0,
    String? notes,
    String? imagePath,
  }) async {
    final id = _uuid.v4();
    final code = _newQrCode('PT');
    final now = DateTime.now();
    await db.into(db.parties).insert(
          PartiesCompanion.insert(
            id: id,
            qrCode: code,
            name: name,
            role: role,
            phone: Value(phone),
            phone2: Value(phone2),
            address: Value(address),
            city: Value(city),
            creditLimit: Value(creditLimit),
            notes: Value(notes),
            imagePath: Value(imagePath),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await enqueueSync(
      db,
      collection: 'parties',
      docId: id,
      payload: {
        'qrCode': code,
        'name': name,
        'role': role,
        'phone': phone,
        'phone2': phone2,
        'address': address,
        'city': city,
        'creditLimit': creditLimit,
        'balance': 0,
        'notes': notes,
        'imagePath': imagePath,
        'isActive': true,
        'updatedAt': now.toIso8601String(),
      },
    );
    return id;
  }

  Future<Party?> partyByQrCode(String qrCode) => (db.select(db.parties)
        ..where((t) => t.qrCode.equals(qrCode) & t.isActive.equals(true)))
      .getSingleOrNull();

  Future<Party?> resolvePartyQr(String raw) async {
    final byCode = await partyByQrCode(raw);
    if (byCode != null) return byCode;
    return partyById(raw);
  }

  Future<void> updateParty({
    required String id,
    String? name,
    String? role,
    String? phone,
    String? phone2,
    String? address,
    String? city,
    double? creditLimit,
    String? notes,
    String? imagePath,
    bool clearImage = false,
    bool? isActive,
  }) async {
    final now = DateTime.now();
    await (db.update(db.parties)..where((t) => t.id.equals(id))).write(
      PartiesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        role: role == null ? const Value.absent() : Value(role),
        phone: phone == null ? const Value.absent() : Value(phone),
        phone2: phone2 == null ? const Value.absent() : Value(phone2),
        address: address == null ? const Value.absent() : Value(address),
        city: city == null ? const Value.absent() : Value(city),
        creditLimit:
            creditLimit == null ? const Value.absent() : Value(creditLimit),
        notes: notes == null ? const Value.absent() : Value(notes),
        imagePath: clearImage
            ? const Value(null)
            : imagePath == null
                ? const Value.absent()
                : Value(imagePath),
        isActive: isActive == null ? const Value.absent() : Value(isActive),
        updatedAt: Value(now),
      ),
    );
    final p = await partyById(id);
    if (p != null) {
      await enqueueSync(
        db,
        collection: 'parties',
        docId: id,
        payload: {
          'qrCode': p.qrCode,
          'name': p.name,
          'role': p.role,
          'phone': p.phone,
          'balance': p.balance,
          'imagePath': p.imagePath,
          'isActive': p.isActive,
          'updatedAt': now.toIso8601String(),
        },
      );
    }
  }

  Future<void> softDeleteParty(String id) => updateParty(id: id, isActive: false);

  Future<String> createBill({
    required String partyId,
    required String kind,
    required List<
            ({
              String description,
              String? itemId,
              double qty,
              double unitPrice,
              String? unit,
              double lineDiscount
            })>
        lines,
    String? note,
    String? locationId,
    double discount = 0,
    double tax = 0,
    String? createdByOwnerId,
    /// credit | cash | online
    String paymentMethod = 'credit',
  }) async {
    final billId = _uuid.v4();
    final code = _newQrCode('BL');
    final now = DateTime.now();
    final linesSum = lines.fold<double>(
      0,
      (s, l) => s + (l.qty * l.unitPrice - l.lineDiscount),
    );
    final total = linesSum - discount + tax;
    final billNo = 'B-${now.millisecondsSinceEpoch % 1000000}';
    final paidNow =
        paymentMethod == 'cash' || paymentMethod == 'online';
    // Sale credit: they owe us (+). Purchase credit: we owe them (−).
    final balanceDelta = paidNow
        ? 0.0
        : (kind == 'purchase' ? -total : total);

    String? resolvedLocationId = locationId;
    if (resolvedLocationId == null || resolvedLocationId.isEmpty) {
      final locs = await (db.select(db.locations)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      if (locs.isNotEmpty) resolvedLocationId = locs.first.id;
    }

    final syncStockEvents = <Map<String, dynamic>>[];
    final syncBalanceKeys = <({String itemId, String locationId})>{};
    String? syncPayId;
    String? syncCashId;
    String? syncPayDirection;

    await db.transaction(() async {
      await db.into(db.bills).insert(
            BillsCompanion.insert(
              id: billId,
              qrCode: code,
              billNo: Value(billNo),
              partyId: partyId,
              locationId: Value(resolvedLocationId),
              kind: Value(kind),
              total: Value(total),
              discount: Value(discount),
              tax: Value(tax),
              paid: Value(paidNow ? total : 0),
              status: Value(paidNow ? 'paid' : 'open'),
              note: Value(note),
              createdByOwnerId: Value(createdByOwnerId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      var i = 0;
      for (final line in lines) {
        final lineTotal = line.qty * line.unitPrice - line.lineDiscount;
        final lineId = '$billId-L$i';
        await db.into(db.billLines).insert(
              BillLinesCompanion.insert(
                id: lineId,
                billId: billId,
                itemId: Value(line.itemId),
                description: line.description,
                qty: line.qty,
                unit: Value(line.unit),
                unitPrice: line.unitPrice,
                lineDiscount: Value(line.lineDiscount),
                lineTotal: Value(lineTotal),
                sortOrder: Value(i),
              ),
            );
        i++;

        // Spinal cord: every bill line with an item moves stock.
        final itemId = line.itemId;
        final locId = resolvedLocationId;
        if (itemId != null && locId != null && line.qty > 0) {
          final stockType = kind == 'purchase' ? 'purchase' : 'sale';
          final balRows = await (db.select(db.stockBalances)
                ..where(
                  (t) =>
                      t.itemId.equals(itemId) & t.locationId.equals(locId),
                ))
              .get();
          final current = balRows.isEmpty ? 0.0 : balRows.first.qty;
          final next = stockType == 'purchase'
              ? current + line.qty
              : current - line.qty;
          if (stockType == 'sale' && next < -1e-9) {
            throw StateError('Stock kam hai');
          }
          if (balRows.isEmpty) {
            await db.into(db.stockBalances).insert(
                  StockBalancesCompanion.insert(
                    itemId: itemId,
                    locationId: locId,
                    qty: Value(next < 0 ? 0 : next),
                    updatedAt: now,
                  ),
                );
          } else {
            await (db.update(db.stockBalances)
                  ..where(
                    (t) =>
                        t.itemId.equals(itemId) & t.locationId.equals(locId),
                  ))
                .write(
              StockBalancesCompanion(
                qty: Value(next < 0 ? 0 : next),
                updatedAt: Value(now),
              ),
            );
          }
          final eventId = _uuid.v4();
          await db.into(db.stockEvents).insert(
                StockEventsCompanion.insert(
                  id: eventId,
                  type: stockType,
                  itemId: itemId,
                  locationId: locId,
                  qty: line.qty,
                  unitCost: Value(line.unitPrice),
                  refType: const Value('bill'),
                  refId: Value(billId),
                  actorOwnerId: Value(createdByOwnerId),
                  note: Value(line.description),
                  at: now,
                  createdAt: now,
                ),
              );
          syncStockEvents.add({
            'id': eventId,
            'type': stockType,
            'itemId': itemId,
            'locationId': locId,
            'qty': line.qty,
            'unitCost': line.unitPrice,
            'refType': 'bill',
            'refId': billId,
            'actorOwnerId': createdByOwnerId,
            'note': line.description,
            'at': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          });
          syncBalanceKeys.add((itemId: itemId, locationId: locId));
        }
      }

      if (balanceDelta != 0) {
        final party = await (db.select(db.parties)
              ..where((t) => t.id.equals(partyId)))
            .getSingle();
        await (db.update(db.parties)..where((t) => t.id.equals(partyId)))
            .write(
          PartiesCompanion(
            balance: Value(party.balance + balanceDelta),
            updatedAt: Value(now),
          ),
        );
      }

      if (paidNow && total > 0) {
        final payId = _uuid.v4();
        final payDirection = kind == 'purchase' ? 'out' : 'in';
        syncPayId = payId;
        syncCashId = _uuid.v4();
        syncPayDirection = payDirection;
        await db.into(db.payments).insert(
              PaymentsCompanion.insert(
                id: payId,
                partyId: partyId,
                billId: Value(billId),
                amount: total,
                method: Value(paymentMethod),
                direction: Value(payDirection),
                note: Value('Bill $billNo'),
                at: now,
                createdByOwnerId: Value(createdByOwnerId),
                createdAt: now,
              ),
            );
        await db.into(db.cashEntries).insert(
              CashEntriesCompanion.insert(
                id: syncCashId!,
                kind: payDirection == 'in' ? 'in' : 'out',
                amount: total,
                source: Value(paymentMethod),
                category: Value(
                  kind == 'purchase' ? 'Bill purchase' : 'Bill sale',
                ),
                refType: const Value('bill'),
                refId: Value(billId),
                note: Value('Bill $billNo · $paymentMethod'),
                actorOwnerId: Value(createdByOwnerId),
                at: now,
                createdAt: now,
              ),
            );
      }
    });

    await enqueueSync(
      db,
      collection: 'bills',
      docId: billId,
      payload: {
        'qrCode': code,
        'billNo': billNo,
        'partyId': partyId,
        'locationId': resolvedLocationId,
        'kind': kind,
        'total': total,
        'discount': discount,
        'tax': tax,
        'paid': paidNow ? total : 0,
        'status': paidNow ? 'paid' : 'open',
        'paymentMethod': paymentMethod,
        'note': note,
        'createdByOwnerId': createdByOwnerId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'lines': [
          for (var i = 0; i < lines.length; i++)
            {
              'id': '$billId-L$i',
              'itemId': lines[i].itemId,
              'description': lines[i].description,
              'qty': lines[i].qty,
              'unit': lines[i].unit,
              'unitPrice': lines[i].unitPrice,
              'lineDiscount': lines[i].lineDiscount,
              'lineTotal':
                  lines[i].qty * lines[i].unitPrice - lines[i].lineDiscount,
              'sortOrder': i,
            },
        ],
      },
    );

    for (final ev in syncStockEvents) {
      await enqueueSync(
        db,
        collection: 'stock_events',
        docId: ev['id'] as String,
        payload: ev,
      );
    }
    for (final key in syncBalanceKeys) {
      final rows = await (db.select(db.stockBalances)
            ..where(
              (t) =>
                  t.itemId.equals(key.itemId) &
                  t.locationId.equals(key.locationId),
            ))
          .get();
      final q = rows.isEmpty ? 0.0 : rows.first.qty;
      await enqueueSync(
        db,
        collection: 'stock_balances',
        docId: '${key.itemId}__${key.locationId}',
        payload: {
          'itemId': key.itemId,
          'locationId': key.locationId,
          'qty': q,
          'updatedAt': now.toIso8601String(),
        },
      );
    }
    if (syncPayId != null) {
      await enqueueSync(
        db,
        collection: 'payments',
        docId: syncPayId!,
        payload: {
          'partyId': partyId,
          'billId': billId,
          'amount': total,
          'method': paymentMethod,
          'direction': syncPayDirection,
          'note': 'Bill $billNo',
          'at': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
    }
    if (syncCashId != null) {
      await enqueueSync(
        db,
        collection: 'cash_entries',
        docId: syncCashId!,
        payload: {
          'kind': syncPayDirection == 'in' ? 'in' : 'out',
          'amount': total,
          'source': paymentMethod,
          'category': kind == 'purchase' ? 'Bill purchase' : 'Bill sale',
          'refType': 'bill',
          'refId': billId,
          'note': 'Bill $billNo · $paymentMethod',
          'at': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
    }
    if (balanceDelta != 0) {
      final party = await partyById(partyId);
      if (party != null) {
        await enqueueSync(
          db,
          collection: 'parties',
          docId: partyId,
          payload: {
            'qrCode': party.qrCode,
            'name': party.name,
            'role': party.role,
            'phone': party.phone,
            'balance': party.balance,
            'imagePath': party.imagePath,
            'isActive': party.isActive,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    }
    return billId;
  }

  Future<Bill?> billByQrCode(String qrCode) =>
      (db.select(db.bills)..where((t) => t.qrCode.equals(qrCode)))
          .getSingleOrNull();

  Future<Bill?> resolveBillQr(String raw) async {
    final byCode = await billByQrCode(raw);
    if (byCode != null) return byCode;
    return billById(raw);
  }

  Future<void> voidBill(String billId) async {
    final bill = await billById(billId);
    if (bill == null || bill.status == 'void') return;
    final now = DateTime.now();
    final unpaid = bill.total - bill.paid;
    // Sale credit undo: −unpaid. Purchase credit undo: +unpaid.
    final balanceUndo = bill.kind == 'purchase' ? unpaid : -unpaid;
    await db.transaction(() async {
      await (db.update(db.bills)..where((t) => t.id.equals(billId))).write(
        BillsCompanion(
          status: const Value('void'),
          updatedAt: Value(now),
        ),
      );
      if (unpaid.abs() > 1e-9) {
        final party = await (db.select(db.parties)
              ..where((t) => t.id.equals(bill.partyId)))
            .getSingle();
        await (db.update(db.parties)..where((t) => t.id.equals(bill.partyId)))
            .write(
          PartiesCompanion(
            balance: Value(party.balance + balanceUndo),
            updatedAt: Value(now),
          ),
        );
      }
    });
    final voided = await billById(billId);
    if (voided != null) {
      final lines = await linesFor(billId);
      await enqueueSync(
        db,
        collection: 'bills',
        docId: billId,
        payload: {
          'qrCode': voided.qrCode,
          'billNo': voided.billNo,
          'partyId': voided.partyId,
          'locationId': voided.locationId,
          'kind': voided.kind,
          'total': voided.total,
          'discount': voided.discount,
          'tax': voided.tax,
          'paid': voided.paid,
          'status': voided.status,
          'note': voided.note,
          'createdByOwnerId': voided.createdByOwnerId,
          'updatedAt': now.toIso8601String(),
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
        },
      );
    }
    if (unpaid.abs() > 1e-9) {
      final party = await partyById(bill.partyId);
      if (party != null) {
        await enqueueSync(
          db,
          collection: 'parties',
          docId: party.id,
          payload: {
            'qrCode': party.qrCode,
            'name': party.name,
            'role': party.role,
            'phone': party.phone,
            'balance': party.balance,
            'isActive': party.isActive,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    }
  }

  Future<void> recordPayment({
    required String partyId,
    required double amount,
    String? billId,
    String method = 'cash',
    String direction = 'in',
    String? reference,
    String? note,
    String? createdByOwnerId,
  }) async {
    final id = _uuid.v4();
    final cashId = _uuid.v4();
    final now = DateTime.now();
    final signed = direction == 'out' ? -amount : amount;
    final touchCash = method == 'cash' || method == 'online';
    await db.transaction(() async {
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              id: id,
              partyId: partyId,
              billId: Value(billId),
              amount: amount,
              method: Value(method),
              direction: Value(direction),
              reference: Value(reference),
              note: Value(note),
              at: now,
              createdByOwnerId: Value(createdByOwnerId),
              createdAt: now,
            ),
          );
      final party = await (db.select(db.parties)
            ..where((t) => t.id.equals(partyId)))
          .getSingle();
      await (db.update(db.parties)..where((t) => t.id.equals(partyId))).write(
        PartiesCompanion(
          balance: Value(party.balance - signed),
          updatedAt: Value(now),
        ),
      );
      if (billId != null) {
        final bill = await (db.select(db.bills)
              ..where((t) => t.id.equals(billId)))
            .getSingle();
        final paid = bill.paid + amount;
        await (db.update(db.bills)..where((t) => t.id.equals(billId))).write(
          BillsCompanion(
            paid: Value(paid),
            status: Value(
              paid >= bill.total
                  ? 'paid'
                  : paid > 0
                      ? 'partial'
                      : 'open',
            ),
            updatedAt: Value(now),
          ),
        );
      }
      if (touchCash && amount > 0) {
        await db.into(db.cashEntries).insert(
              CashEntriesCompanion.insert(
                id: cashId,
                kind: direction == 'out' ? 'out' : 'in',
                amount: amount,
                source: Value(method),
                category: const Value('Party payment'),
                refType: const Value('payment'),
                refId: Value(id),
                note: Value(note ?? 'Payment · $method'),
                actorOwnerId: Value(createdByOwnerId),
                at: now,
                createdAt: now,
              ),
            );
      }
    });
    await enqueueSync(
      db,
      collection: 'payments',
      docId: id,
      payload: {
        'partyId': partyId,
        'billId': billId,
        'amount': amount,
        'method': method,
        'direction': direction,
        'reference': reference,
        'note': note,
        'at': now.toIso8601String(),
      },
    );
    if (touchCash && amount > 0) {
      await enqueueSync(
        db,
        collection: 'cash_entries',
        docId: cashId,
        payload: {
          'kind': direction == 'out' ? 'out' : 'in',
          'amount': amount,
          'source': method,
          'category': 'Party payment',
          'refType': 'payment',
          'refId': id,
          'at': now.toIso8601String(),
        },
      );
    }
    final party = await partyById(partyId);
    if (party != null) {
      await enqueueSync(
        db,
        collection: 'parties',
        docId: partyId,
        payload: {
          'qrCode': party.qrCode,
          'name': party.name,
          'role': party.role,
          'phone': party.phone,
          'balance': party.balance,
          'isActive': party.isActive,
          'updatedAt': now.toIso8601String(),
        },
      );
    }
    if (billId != null) {
      final bill = await billById(billId);
      if (bill != null) {
        await enqueueSync(
          db,
          collection: 'bills',
          docId: billId,
          payload: {
            'qrCode': bill.qrCode,
            'billNo': bill.billNo,
            'partyId': bill.partyId,
            'locationId': bill.locationId,
            'kind': bill.kind,
            'total': bill.total,
            'paid': bill.paid,
            'status': bill.status,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    }
  }

  Future<List<BillLine>> linesFor(String billId) =>
      (db.select(db.billLines)
            ..where((t) => t.billId.equals(billId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
}

class FactoryRepository {
  FactoryRepository(this.db);
  final AppDatabase db;

  Stream<List<BomRecipe>> watchRecipes({bool activeOnly = true}) {
    final q = db.select(db.bomRecipes)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (activeOnly) q.where((t) => t.isActive.equals(true));
    return q.watch();
  }

  Stream<List<ProductionRun>> watchRuns() => (db.select(db.productionRuns)
        ..orderBy([(t) => OrderingTerm.desc(t.at)]))
      .watch();

  Future<List<BomLine>> linesFor(String recipeId) =>
      (db.select(db.bomLines)
            ..where((t) => t.recipeId.equals(recipeId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<String> addRecipe({
    required String name,
    required String finishedItemId,
    required double yieldQty,
    String? yieldUnit,
    String? notes,
    required List<({String ingredientItemId, double qty, String? unit, double wasteFactor})>
        lines,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.into(db.bomRecipes).insert(
            BomRecipesCompanion.insert(
              id: id,
              finishedItemId: finishedItemId,
              name: name,
              yieldQty: Value(yieldQty),
              yieldUnit: Value(yieldUnit),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      var i = 0;
      for (final line in lines) {
        await db.into(db.bomLines).insert(
              BomLinesCompanion.insert(
                id: _uuid.v4(),
                recipeId: id,
                ingredientItemId: line.ingredientItemId,
                qty: line.qty,
                unit: Value(line.unit),
                wasteFactor: Value(line.wasteFactor),
                sortOrder: Value(i++),
              ),
            );
      }
    });
    final lineRows = await linesFor(id);
    await enqueueSync(
      db,
      collection: 'bom_recipes',
      docId: id,
      payload: {
        'name': name,
        'finishedItemId': finishedItemId,
        'yieldQty': yieldQty,
        'yieldUnit': yieldUnit,
        'notes': notes,
        'isActive': true,
        'updatedAt': now.toIso8601String(),
        'lines': [
          for (final line in lineRows)
            {
              'id': line.id,
              'ingredientItemId': line.ingredientItemId,
              'qty': line.qty,
              'unit': line.unit,
              'wasteFactor': line.wasteFactor,
              'sortOrder': line.sortOrder,
            },
        ],
      },
    );
    return id;
  }

  Future<BomRecipe?> recipeById(String id) =>
      (db.select(db.bomRecipes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateRecipe({
    required String id,
    required String name,
    required String finishedItemId,
    required double yieldQty,
    String? yieldUnit,
    String? notes,
    required List<({String ingredientItemId, double qty, String? unit, double wasteFactor})>
        lines,
  }) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.bomRecipes)..where((t) => t.id.equals(id))).write(
            BomRecipesCompanion(
              name: Value(name),
              finishedItemId: Value(finishedItemId),
              yieldQty: Value(yieldQty),
              yieldUnit: Value(yieldUnit),
              notes: Value(notes),
              updatedAt: Value(now),
            ),
          );
      await (db.delete(db.bomLines)..where((t) => t.recipeId.equals(id))).go();
      var i = 0;
      for (final line in lines) {
        await db.into(db.bomLines).insert(
              BomLinesCompanion.insert(
                id: _uuid.v4(),
                recipeId: id,
                ingredientItemId: line.ingredientItemId,
                qty: line.qty,
                unit: Value(line.unit),
                wasteFactor: Value(line.wasteFactor),
                sortOrder: Value(i++),
              ),
            );
      }
    });
    final lineRows = await linesFor(id);
    await enqueueSync(
      db,
      collection: 'bom_recipes',
      docId: id,
      payload: {
        'name': name,
        'finishedItemId': finishedItemId,
        'yieldQty': yieldQty,
        'yieldUnit': yieldUnit,
        'notes': notes,
        'updatedAt': now.toIso8601String(),
        'lines': [
          for (final line in lineRows)
            {
              'id': line.id,
              'ingredientItemId': line.ingredientItemId,
              'qty': line.qty,
              'unit': line.unit,
              'wasteFactor': line.wasteFactor,
              'sortOrder': line.sortOrder,
            },
        ],
      },
    );
  }

  Future<void> softDeleteRecipe(String id) async {
    final now = DateTime.now();
    await (db.update(db.bomRecipes)..where((t) => t.id.equals(id))).write(
      BomRecipesCompanion(
        isActive: const Value(false),
        updatedAt: Value(now),
      ),
    );
    final recipe = await recipeById(id);
    if (recipe == null) return;
    final lineRows = await linesFor(id);
    await enqueueSync(
      db,
      collection: 'bom_recipes',
      docId: id,
      payload: {
        'name': recipe.name,
        'finishedItemId': recipe.finishedItemId,
        'yieldQty': recipe.yieldQty,
        'yieldUnit': recipe.yieldUnit,
        'notes': recipe.notes,
        'isActive': false,
        'updatedAt': now.toIso8601String(),
        'lines': [
          for (final line in lineRows)
            {
              'id': line.id,
              'ingredientItemId': line.ingredientItemId,
              'qty': line.qty,
              'unit': line.unit,
              'wasteFactor': line.wasteFactor,
              'sortOrder': line.sortOrder,
            },
        ],
      },
    );
  }

  Future<String> runProduction({
    required String recipeId,
    required String factoryLocationId,
    required double batches,
    String? note,
    String? actorOwnerId,
  }) async {
    final recipe = await (db.select(db.bomRecipes)
          ..where((t) => t.id.equals(recipeId)))
        .getSingle();
    final lines = await linesFor(recipeId);
    final inv = InventoryRepository(db);
    final runId = _uuid.v4();
    final now = DateTime.now();
    final finishedQty = recipe.yieldQty * batches;

    // Stock moves first (each event syncs); then record the run.
    for (final line in lines) {
      final need = line.qty * batches * (1 + line.wasteFactor);
      await inv.applyStockEvent(
        type: 'adjust_out',
        itemId: line.ingredientItemId,
        locationId: factoryLocationId,
        qty: need,
        note: note ?? 'Nuskha: ${recipe.name}',
        refType: 'production_run',
        refId: runId,
        actorOwnerId: actorOwnerId,
      );
    }
    await inv.applyStockEvent(
      type: 'produce',
      itemId: recipe.finishedItemId,
      locationId: factoryLocationId,
      qty: finishedQty,
      note: note ?? 'Tayyar: ${recipe.name}',
      refType: 'production_run',
      refId: runId,
      actorOwnerId: actorOwnerId,
    );
    await db.into(db.productionRuns).insert(
          ProductionRunsCompanion.insert(
            id: runId,
            recipeId: recipeId,
            factoryLocationId: factoryLocationId,
            batches: batches,
            finishedQty: finishedQty,
            note: Value(note),
            actorOwnerId: Value(actorOwnerId),
            at: now,
            createdAt: now,
          ),
        );

    await enqueueSync(
      db,
      collection: 'production_runs',
      docId: runId,
      payload: {
        'recipeId': recipeId,
        'factoryLocationId': factoryLocationId,
        'batches': batches,
        'finishedQty': finishedQty,
        'note': note,
        'actorOwnerId': actorOwnerId,
        'at': now.toIso8601String(),
      },
    );
    return runId;
  }
}

class DayCheckRepository {
  DayCheckRepository(this.db);
  final AppDatabase db;

  Stream<List<DayCheck>> watchChecks() => (db.select(db.dayChecks)
        ..orderBy([(t) => OrderingTerm.desc(t.at)]))
      .watch();

  Future<String> add({
    required String locationId,
    required String kind,
    String? note,
    String? ownerId,
    double? cashCount,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.dayChecks).insert(
          DayChecksCompanion.insert(
            id: id,
            locationId: locationId,
            kind: kind,
            ownerId: Value(ownerId),
            cashCount: Value(cashCount),
            at: now,
            note: Value(note),
            createdAt: now,
          ),
        );
    await enqueueSync(
      db,
      collection: 'day_checks',
      docId: id,
      payload: {
        'locationId': locationId,
        'kind': kind,
        'ownerId': ownerId,
        'cashCount': cashCount,
        'note': note,
        'at': now.toIso8601String(),
      },
    );
    return id;
  }

  Future<void> delete(String id) async {
    await (db.delete(db.dayChecks)..where((t) => t.id.equals(id))).go();
  }
}
