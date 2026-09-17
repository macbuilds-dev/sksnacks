import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_providers.dart';
import '../core/sync/sync_worker.dart';
import '../l10n/app_copy.dart';
import 'kitsch_widgets.dart';

/// Safe row inside stickers (avoids fragile ListTile theme paths).
class StickerRow extends StatelessWidget {
  const StickerRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

/// Thick kitsch icon chip for page headers / home actions.
class KitschIconButton extends StatelessWidget {
  const KitschIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = Padding(
      padding: const EdgeInsets.only(left: 6),
      child: KitschSticker(
        onTap: onPressed,
        padding: const EdgeInsets.all(10),
        shadowDx: 2,
        shadowDy: 2,
        borderWidth: 2.5,
        radius: 14,
        color: color ?? scheme.tertiary,
        child: Icon(icon, size: 22, color: scheme.onSurface),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// Neubrutalist back control for AppBars (not thin Material arrow).
class KitschBackButton extends StatelessWidget {
  const KitschBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: KitschSticker(
          onTap: () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.all(8),
          shadowDx: 2,
          shadowDy: 2,
          borderWidth: 2.5,
          radius: 12,
          color: scheme.tertiary,
          child: CustomPaint(
            size: const Size(22, 22),
            painter: _KitschArrowPainter(ink: scheme.outline),
          ),
        ),
      ),
    );
  }
}

class _KitschArrowPainter extends CustomPainter {
  _KitschArrowPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()
      ..moveTo(size.width * 0.62, size.height * 0.18)
      ..lineTo(size.width * 0.28, size.height * 0.5)
      ..lineTo(size.width * 0.62, size.height * 0.82);
    canvas.drawPath(path, p);
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.5),
      Offset(size.width * 0.78, size.height * 0.5),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _KitschArrowPainter oldDelegate) =>
      oldDelegate.ink != ink;
}

PreferredSizeWidget kitschAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    title: Text(title),
    leading: const KitschBackButton(),
    leadingWidth: 56,
    actions: actions,
    bottom: bottom,
  );
}

/// Scrollable dialog body so forms never explode the Column height.
Widget dialogForm(List<Widget> children) {
  return SizedBox(
    width: double.maxFinite,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

Future<void> runCloudSync(
  BuildContext context,
  WidgetRef ref, {
  bool forceFullMirror = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        forceFullMirror ? 'Force sync / full mirror…' : Copy.syncWorking,
      ),
      duration: const Duration(seconds: 90),
    ),
  );

  SyncFlushResult result;
  try {
    result = await ref
        .read(syncWorkerProvider)
        .syncTwoWay(forceFullMirror: forceFullMirror);
  } catch (_) {
    ref.invalidate(pendingSyncCountProvider);
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text(Copy.syncFail)));
    return;
  }

  ref.invalidate(pendingSyncCountProvider);
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  final String msg;
  if (result.offline) {
    msg = result.remaining == 0
        ? Copy.syncOffline
        : '${Copy.syncOffline} (${result.remaining} baaki)';
  } else if (result.failed > 0 && result.sent == 0 && result.pulled == 0) {
    msg = Copy.syncFail;
  } else if (result.sent > 0 || result.pulled > 0) {
    msg = Copy.syncOk;
  } else if (result.remaining > 0) {
    msg = '${result.remaining} ${Copy.syncPending}. Phir try karo.';
  } else {
    msg = Copy.syncOk;
  }

  messenger.showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
  );
}

void showNeed(BuildContext context, String message) {
  _showAppSnack(
    context,
    message,
    icon: Icons.info_outline,
    background: null,
  );
}

void showOk(BuildContext context, String message) {
  _showAppSnack(
    context,
    message,
    icon: Icons.check_circle_outline,
    background: const Color(0xFF1B7F4E),
  );
}

void showFail(BuildContext context, String message) {
  _showAppSnack(
    context,
    message,
    icon: Icons.error_outline,
    background: const Color(0xFFB3261E),
  );
}

/// Confirm before mutating CRUD / danger actions (all apps pattern).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

void _showAppSnack(
  BuildContext context,
  String message, {
  required IconData icon,
  Color? background,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
      backgroundColor: background,
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    ),
  );
}
