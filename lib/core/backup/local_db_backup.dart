import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Local SQLite + media backup (same data that syncs to remote when online).
class LocalDbBackup {
  static const dbName = 'sksnacks_local.db';

  static Future<Directory> docsDir() => getApplicationDocumentsDirectory();

  static Future<File> dbFile() async {
    final dir = await docsDir();
    return File(p.join(dir.path, dbName));
  }

  static String suggestedFileName() =>
      'sksnacks_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

  static Future<List<File>> _sqliteSidecars(Directory dir) async {
    final names = [dbName, '$dbName-wal', '$dbName-shm'];
    final out = <File>[];
    for (final n in names) {
      final f = File(p.join(dir.path, n));
      if (await f.exists()) out.add(f);
    }
    return out;
  }

  /// Build zip in temp and return the file.
  static Future<File> buildZipFile() async {
    final dir = await docsDir();
    final db = await dbFile();
    if (!await db.exists()) {
      throw StateError('Backup file nahi mili');
    }

    final tmp = await Directory.systemTemp.createTemp('sk_backup_');
    final zipPath = p.join(tmp.path, suggestedFileName());

    final encoder = ZipFileEncoder()..create(zipPath);
    for (final f in await _sqliteSidecars(dir)) {
      await encoder.addFile(f, p.basename(f.path));
    }
    final media = Directory(p.join(dir.path, 'media'));
    if (await media.exists()) {
      await encoder.addDirectory(media, includeDirName: true);
    }
    final receipts = Directory(p.join(dir.path, 'receipts'));
    if (await receipts.exists()) {
      await encoder.addDirectory(receipts, includeDirName: true);
    }
    await encoder.close();
    return File(zipPath);
  }

  /// Zip DB (+ wal/shm) and media/receipts folders, then share sheet.
  static Future<void> exportAndShare() async {
    final zip = await buildZipFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zip.path, mimeType: 'application/zip')],
        text: 'SHSnacks local DB backup',
      ),
    );
  }

  /// Let user pick where to save the zip (Downloads / Files / …).
  /// Returns the saved [Uri], or `null` if cancelled.
  static Future<Uri?> exportAndSaveLocal() async {
    final zip = await buildZipFile();
    final bytes = await zip.readAsBytes();
    final name = p.basename(zip.path);
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Backup kahan save karna hai?',
      fileName: name,
      bytes: bytes,
      mimeType: 'application/zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return uri;
  }

  /// Pick a backup zip/db. Returns bytes + original name, or null if cancelled.
  static Future<({Uint8List bytes, String name})?> pickBackupBytes() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'db'],
      dialogTitle: 'Backup file choose karo',
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (bytes: bytes, name: file.name);
  }

  /// Replace local DB + media from picked bytes. Caller must close DB first.
  static Future<void> importFromBytes({
    required Uint8List bytes,
    required String name,
  }) async {
    final dir = await docsDir();
    final lower = name.toLowerCase();

    if (lower.endsWith('.db')) {
      await _wipeSqlite(dir);
      await File(p.join(dir.path, dbName)).writeAsBytes(bytes, flush: true);
      return;
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    await _wipeSqlite(dir);

    final mediaRoot = Directory(p.join(dir.path, 'media'));
    final receiptsRoot = Directory(p.join(dir.path, 'receipts'));
    if (await mediaRoot.exists()) {
      await mediaRoot.delete(recursive: true);
    }
    if (await receiptsRoot.exists()) {
      await receiptsRoot.delete(recursive: true);
    }

    for (final file in archive) {
      final entryName = file.name.replaceAll('\\', '/');
      if (entryName.endsWith('/')) continue;
      // Avoid zip-slip outside docs dir.
      final outPath = p.normalize(p.join(dir.path, entryName));
      if (!outPath.startsWith(p.normalize(dir.path))) continue;
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      if (file.isFile) {
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      }
    }
    debugPrint('Local backup imported into ${dir.path}');
  }

  /// Replace local DB + media from a backup zip. Caller must close DB first.
  static Future<void> importFromPicker() async {
    final picked = await pickBackupBytes();
    if (picked == null) {
      throw StateError('Koi file nahi chuni');
    }
    await importFromBytes(bytes: picked.bytes, name: picked.name);
  }

  static Future<void> _wipeSqlite(Directory dir) async {
    for (final f in await _sqliteSidecars(dir)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
