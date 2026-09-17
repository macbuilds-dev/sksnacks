import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../core/backup/local_db_backup.dart';
import '../../core/sync/sync_providers.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/repo_providers.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/auth_state.dart';
import '../../l10n/app_copy.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final inv = ref.watch(inventoryRepoProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: kitschAppBar(context, title: Copy.settingsTitle),
      body: KitschBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              Copy.settingsCore,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              Copy.settingsCoreHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            KitschSticker(
              color: scheme.tertiary,
              child: StickerRow(
                leading: const Icon(Icons.groups),
                title: Copy.settingsOwners,
                subtitle: auth == null
                    ? '—'
                    : [
                        auth.displayName,
                        if (auth.email != null) auth.email!,
                        if (auth.isPlatformAdmin) 'platform',
                        auth.role.name,
                      ].join(' · '),
              ),
            ),
            if (auth != null &&
                (auth.isPlatformAdmin || auth.role == ShopRole.primary)) ...[
              const SizedBox(height: 12),
              KitschSticker(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Secondary emails (max 2)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Silent add — owner list remote pe save. Google match pe allow.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _addSecondary(context, ref),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add secondary email'),
                    ),
                  ],
                ),
              ),
            ],
            if (auth?.isPlatformAdmin == true) ...[
              const SizedBox(height: 12),
              KitschSticker(
                color: scheme.secondaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Platform · force sync',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Force full mirror?'),
                            content: const Text(
                              'Pull + push full local mirror to nested baithak paths.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(Copy.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Force sync'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await runCloudSync(
                            context,
                            ref,
                            forceFullMirror: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.bolt),
                      label: const Text('Force push / full mirror'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            KitschSticker(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StickerRow(
                    leading: const Icon(Icons.cloud_sync),
                    title: Copy.settingsSync,
                    subtitle: pending.when(
                      data: (c) => c == 0
                          ? 'Sab clear'
                          : '$c ${Copy.syncPending}',
                      loading: () => '...',
                      error: (_, _) => Copy.settingsSyncHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Copy.settingsSyncHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => runCloudSync(context, ref),
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text(Copy.syncNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              Copy.settingsBackup,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            KitschSticker(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _exportBackup(context, ref),
                    icon: const Icon(Icons.upload_file),
                    label: const Text(Copy.exportBackup),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Copy.settingsBackupHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _importBackup(context, ref),
                    icon: const Icon(Icons.download),
                    label: const Text(Copy.importBackup),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Copy.settingsLocations,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addLocation(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text(Copy.settingsAddLocation),
                ),
              ],
            ),
            StreamBuilder<List<Location>>(
              stream: inv.watchLocations(activeOnly: true),
              builder: (context, snap) {
                final locs = snap.data ?? [];
                if (locs.isEmpty) {
                  return const Text('Abhi koi jagah nahi');
                }
                return Column(
                  children: locs
                      .map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KitschSticker(
                            color: scheme.surface,
                            child: StickerRow(
                              title: l.name,
                              subtitle: '${l.kind}'
                                  '${l.address != null ? ' · ${l.address}' : ''}',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteLocation(
                                      context,
                                      ref,
                                      l,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Andar aa ke: ${auth?.displayName ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by Baithak',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSecondary(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secondary email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@gmail.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !context.mounted) return;
    final err =
        await ref.read(authControllerProvider.notifier).addSecondaryEmail(email);
    if (!context.mounted) return;
    if (err != null) {
      showFail(context, err);
    } else {
      showOk(context, 'Secondary saved on remote');
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text(Copy.exportSavePhone),
              subtitle: const Text(Copy.exportSaveHint),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text(Copy.exportShare),
              subtitle: const Text(Copy.exportShareHint),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text(Copy.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text(Copy.exportWorking)),
    );
    try {
      try {
        await ref.read(appDatabaseProvider).customStatement(
              'PRAGMA wal_checkpoint(TRUNCATE)',
            );
      } catch (_) {}
      if (choice == 'save') {
        final uri = await LocalDbBackup.exportAndSaveLocal();
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        if (uri == null) {
          showNeed(context, Copy.importCancel);
        } else {
          showOk(context, Copy.exportOk);
        }
      } else {
        await LocalDbBackup.exportAndShare();
        messenger.hideCurrentSnackBar();
        if (context.mounted) showOk(context, Copy.exportShareReady);
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) showFail(context, 'Backup fail: $e');
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Copy.importConfirmTitle),
        content: const Text(Copy.importConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Copy.importBackup),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final picked = await LocalDbBackup.pickBackupBytes();
    if (picked == null) {
      if (context.mounted) showNeed(context, Copy.importCancel);
      return;
    }
    if (!context.mounted) return;

    showNeed(context, Copy.importWorking);
    try {
      final db = ref.read(appDatabaseProvider);
      try {
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}
      await db.close();

      await LocalDbBackup.importFromBytes(
        bytes: picked.bytes,
        name: picked.name,
      );

      ref.invalidate(appDatabaseProvider);
      ref.invalidate(inventoryRepoProvider);
      ref.invalidate(cashRepoProvider);
      ref.invalidate(khataRepoProvider);
      ref.invalidate(factoryRepoProvider);
      ref.invalidate(dayCheckRepoProvider);
      ref.invalidate(syncWorkerProvider);
      ref.invalidate(pendingSyncCountProvider);

      ref.read(appDatabaseProvider);

      if (!context.mounted) return;
      showOk(context, Copy.importOk);
      context.go('/');
    } catch (e) {
      ref.invalidate(appDatabaseProvider);
      if (!context.mounted) return;
      showFail(context, 'Import fail: $e');
    }
  }

  Future<void> _deleteLocation(
    BuildContext context,
    WidgetRef ref,
    Location loc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Copy.locDeleteTitle),
        content: Text('${loc.name}\n\n${Copy.locDeleteBody}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Copy.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(inventoryRepoProvider).deleteLocation(loc.id);
      if (context.mounted) showOk(context, Copy.deletedOk);
    } catch (e) {
      if (context.mounted) showFail(context, '$e');
    }
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final address = TextEditingController();
    var kind = 'shop';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(Copy.settingsAddLocation),
          content: dialogForm([
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: Copy.name),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(kind),
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'factory', child: Text('Factory')),
                DropdownMenuItem(value: 'shop', child: Text('Shop')),
                DropdownMenuItem(value: 'godaam', child: Text('Godaam')),
                DropdownMenuItem(value: 'other', child: Text('Aur jagah')),
              ],
              onChanged: (v) => setLocal(() => kind = v!),
              decoration: const InputDecoration(labelText: Copy.locationKind),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: Copy.address),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(Copy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(Copy.save),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(inventoryRepoProvider).addLocation(
            name: name.text.trim(),
            kind: kind,
            address: address.text.trim().isEmpty ? null : address.text.trim(),
          );
    }
  }
}
