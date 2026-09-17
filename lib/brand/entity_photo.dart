import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/media/entity_media.dart';

/// Square photo thumb — file if present, otherwise kitsch placeholder.
class EntityPhotoThumb extends StatelessWidget {
  const EntityPhotoThumb({
    super.key,
    this.path,
    this.size = 48,
    this.radius = 12,
    this.icon = Icons.image_outlined,
  });

  final String? path;
  final double size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = path != null && path!.isNotEmpty ? File(path!) : null;
    final hasFile = file != null && file.existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outline, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasFile
          ? Image.file(file, fit: BoxFit.cover)
          : ColoredBox(
              color: scheme.secondary.withValues(alpha: 0.35),
              child: Icon(icon, size: size * 0.42, color: scheme.outline),
            ),
    );
  }
}

/// Tappable photo block for forms: preview + camera / gallery.
class EntityPhotoPicker extends StatelessWidget {
  const EntityPhotoPicker({
    super.key,
    required this.path,
    required this.onChanged,
    required this.kind,
    required this.entityId,
    this.label = 'Photo',
    this.placeholderIcon = Icons.add_a_photo_outlined,
  });

  final String? path;
  final ValueChanged<String?> onChanged;
  final String kind;
  final String entityId;
  final String label;
  final IconData placeholderIcon;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final saved = await EntityMedia.pickAndSave(
      kind: kind,
      entityId: entityId,
      source: source,
    );
    if (saved != null) onChanged(saved);
  }

  Future<void> _sheet(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (path != null && path!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'clear') {
      onChanged(null);
      return;
    }
    await _pick(
      context,
      action == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _sheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: path != null &&
                    path!.isNotEmpty &&
                    File(path!).existsSync()
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(path!), fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outline, width: 2),
                          ),
                          child: Text(
                            'Change',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(placeholderIcon, size: 36, color: scheme.outline),
                      const SizedBox(height: 8),
                      Text(
                        'Add photo',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
