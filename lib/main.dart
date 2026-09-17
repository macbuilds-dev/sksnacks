import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/sync/sync_dedupe.dart';
import 'data/local/app_database.dart';
import 'data/local/database_provider.dart';
import 'features/auth/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();

  final db = AppDatabase();
  await seedIfEmpty(db);
  await dedupeLocalBusinessData(db);
  db.close();

  final savedOwner = await loadPersistedOwner();

  runApp(
    ProviderScope(
      overrides: [
        authInitialSessionProvider.overrideWithValue(savedOwner),
        appDatabaseProvider.overrideWith((ref) {
          final instance = AppDatabase();
          ref.onDispose(instance.close);
          return instance;
        }),
      ],
      child: const SkSnacksApp(),
    ),
  );
}
