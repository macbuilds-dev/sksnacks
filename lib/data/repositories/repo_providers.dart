import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_provider.dart';
import 'repositories.dart';

final inventoryRepoProvider = Provider((ref) {
  return InventoryRepository(ref.watch(appDatabaseProvider));
});

final cashRepoProvider = Provider((ref) {
  return CashRepository(ref.watch(appDatabaseProvider));
});

final khataRepoProvider = Provider((ref) {
  return KhataRepository(ref.watch(appDatabaseProvider));
});

final factoryRepoProvider = Provider((ref) {
  return FactoryRepository(ref.watch(appDatabaseProvider));
});

final dayCheckRepoProvider = Provider((ref) {
  return DayCheckRepository(ref.watch(appDatabaseProvider));
});
