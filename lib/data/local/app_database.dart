import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // factory | shop | godaam | other
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get qrCode => text()();
  TextColumn get name => text()();
  TextColumn get nameUr => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get salePrice => real().withDefault(const Constant(0))();
  RealColumn get costPrice => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {qrCode},
      ];
}

class StockBalances extends Table {
  TextColumn get itemId => text()();
  TextColumn get locationId => text()();
  RealColumn get qty => real().withDefault(const Constant(0))();
  RealColumn get reservedQty => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {itemId, locationId};
}

class StockEvents extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get itemId => text()();
  TextColumn get locationId => text()();
  TextColumn get toLocationId => text().nullable()();
  RealColumn get qty => real()();
  RealColumn get unitCost => real().nullable()();
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();
  TextColumn get actorOwnerId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Parties extends Table {
  TextColumn get id => text()();
  TextColumn get qrCode => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // customer | supplier | both
  TextColumn get phone => text().nullable()();
  TextColumn get phone2 => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {qrCode},
      ];
}

class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get qrCode => text()();
  TextColumn get billNo => text().nullable()();
  TextColumn get partyId => text()();
  TextColumn get locationId => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('sale'))();
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get paid => real().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdByOwnerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {qrCode},
      ];
}

class BillLines extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get itemId => text().nullable()();
  TextColumn get description => text()();
  RealColumn get qty => real()();
  TextColumn get unit => text().nullable()();
  RealColumn get unitPrice => real()();
  RealColumn get lineDiscount => real().withDefault(const Constant(0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get partyId => text()();
  TextColumn get billId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get method => text().withDefault(const Constant('cash'))();
  TextColumn get direction => text().withDefault(const Constant('in'))();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get at => dateTime()();
  TextColumn get createdByOwnerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CashEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // in | out
  RealColumn get amount => real()();
  TextColumn get source => text().withDefault(const Constant('cash'))();
  TextColumn get category => text().nullable()();
  TextColumn get locationId => text().nullable()();
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get actorOwnerId => text().nullable()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DayChecks extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text()();
  TextColumn get kind => text()(); // in | out
  TextColumn get ownerId => text().nullable()();
  RealColumn get cashCount => real().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BomRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get finishedItemId => text()();
  TextColumn get name => text()();
  RealColumn get yieldQty => real().withDefault(const Constant(1))();
  TextColumn get yieldUnit => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BomLines extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text()();
  TextColumn get ingredientItemId => text()();
  RealColumn get qty => real()();
  TextColumn get unit => text().nullable()();
  RealColumn get wasteFactor => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductionRuns extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text()();
  TextColumn get factoryLocationId => text()();
  RealColumn get batches => real()();
  RealColumn get finishedQty => real()();
  TextColumn get status => text().withDefault(const Constant('done'))();
  TextColumn get note => text().nullable()();
  TextColumn get actorOwnerId => text().nullable()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get collection => text()();
  TextColumn get docId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

class AuditEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  TextColumn get entity => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get screen => text().nullable()();
  TextColumn get actorOwnerId => text().nullable()();
  TextColumn get metaJson => text().nullable()();
  DateTimeColumn get at => dateTime()();
}

@DriftDatabase(
  tables: [
    Locations,
    Items,
    StockBalances,
    StockEvents,
    Parties,
    Bills,
    BillLines,
    Payments,
    CashEntries,
    DayChecks,
    BomRecipes,
    BomLines,
    ProductionRuns,
    SyncOutbox,
    AuditEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Early v0: rebuild when schema jumps (QR on parties/bills).
          if (from < 4) {
            for (final table in allTables) {
              await m.deleteTable(table.actualTableName);
            }
            await m.createAll();
            return;
          }
          if (from < 5) {
            await m.addColumn(parties, parties.imagePath);
          }
        },
      );

  Future<double> totalStockQty() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(qty), 0) AS total FROM stock_balances',
      readsFrom: {stockBalances},
    ).getSingle();
    return row.read<double>('total');
  }

  /// Inventory worth at retail (qty × sale_price).
  Future<double> totalStockValue() async {
    final row = await customSelect(
      '''
      SELECT COALESCE(SUM(sb.qty * i.sale_price), 0) AS total
      FROM stock_balances sb
      INNER JOIN items i ON i.id = sb.item_id
      WHERE i.is_active = 1
      ''',
      readsFrom: {stockBalances, items},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<double> totalPartyBalance() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM parties WHERE is_active = 1',
      readsFrom: {parties},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<double> cashNet() async {
    final row = await customSelect(
      """
      SELECT COALESCE(SUM(CASE WHEN kind = 'in' THEN amount ELSE -amount END), 0) AS total
      FROM cash_entries
      """,
      readsFrom: {cashEntries},
    ).getSingle();
    return row.read<double>('total');
  }

  Future<int> pendingSyncCount() async {
    final row = await customSelect(
      "SELECT COUNT(*) AS c FROM sync_outbox WHERE status IN ('pending', 'failed')",
      readsFrom: {syncOutbox},
    ).getSingle();
    return row.read<int>('c');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sksnacks_local.db'));
    return NativeDatabase.createInBackground(file);
  });
}
