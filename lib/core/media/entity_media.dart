import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Copies a picked image into app documents so paths survive cache clears.
class EntityMedia {
  static Future<Directory> _dir(String kind) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'media', kind));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> savePicked({
    required String kind,
    required String entityId,
    required String sourcePath,
  }) async {
    final dir = await _dir(kind);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = File(p.join(dir.path, '$entityId$ext'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  static Future<String?> pickAndSave({
    required String kind,
    required String entityId,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    return savePicked(kind: kind, entityId: entityId, sourcePath: x.path);
  }

  /// Temp id before entity is created.
  static String tempId() => 'tmp_${_uuid.v4()}';

  static Future<String?> renameTemp({
    required String kind,
    required String tempPath,
    required String entityId,
  }) async {
    final file = File(tempPath);
    if (!await file.exists()) return tempPath;
    final dir = await _dir(kind);
    final ext = p.extension(tempPath).isEmpty ? '.jpg' : p.extension(tempPath);
    final dest = File(p.join(dir.path, '$entityId$ext'));
    if (dest.path == file.path) return dest.path;
    await file.copy(dest.path);
    try {
      await file.delete();
    } catch (_) {}
    return dest.path;
  }
}
