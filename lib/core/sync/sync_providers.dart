import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import 'sync_worker.dart';

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  return SyncWorker(ref.watch(appDatabaseProvider));
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.pendingSyncCount();
});
