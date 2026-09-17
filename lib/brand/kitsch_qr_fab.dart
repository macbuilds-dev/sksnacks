import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kitsch_widgets.dart';
import '../l10n/app_copy.dart';

const _kFabX = 'qr_fab_x';
const _kFabY = 'qr_fab_y';
const _fabSize = 52.0;

/// Icon-only kitsch QR (same mark as floating QR jadoo).
class KitschQrIcon extends StatelessWidget {
  const KitschQrIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.outline;
    return CustomPaint(
      size: Size.square(size),
      painter: KitschQrPainter(ink: ink),
    );
  }
}

/// Icon-only kitsch QR sticker.
class KitschQrFab extends StatelessWidget {
  const KitschQrFab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KitschSticker(
      padding: const EdgeInsets.all(12),
      color: scheme.tertiary,
      shadowDx: 3,
      shadowDy: 3,
      borderWidth: 3,
      radius: 16,
      child: KitschQrIcon(size: 26, color: scheme.outline),
    );
  }
}

/// Draggable QR for shell tabs only. Dialogs/sheets on the root navigator cover it.
class DraggableQrFab extends StatefulWidget {
  const DraggableQrFab({super.key, required this.bounds});

  final Size bounds;

  @override
  State<DraggableQrFab> createState() => _DraggableQrFabState();
}

class _DraggableQrFabState extends State<DraggableQrFab> {
  Offset? _pos;
  bool _loaded = false;
  Offset _panDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadPos();
  }

  Future<void> _loadPos() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_kFabX);
    final y = prefs.getDouble(_kFabY);
    if (!mounted) return;
    setState(() {
      if (x != null && y != null) _pos = Offset(x, y);
      _loaded = true;
    });
  }

  Future<void> _savePos(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFabX, pos.dx);
    await prefs.setDouble(_kFabY, pos.dy);
  }

  Offset _defaultPos(Size size) => Offset(16, size.height - _fabSize - 16);

  Offset _clamp(Offset raw, Size size) {
    final maxX = size.width - _fabSize - 8;
    final maxY = size.height - _fabSize - 8;
    return Offset(
      raw.dx.clamp(8.0, maxX < 8 ? 8.0 : maxX),
      raw.dy.clamp(8.0, maxY < 8 ? 8.0 : maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final size = widget.bounds;
    final pos = _clamp(_pos ?? _defaultPos(size), size);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Semantics(
        button: true,
        label: Copy.qrTitle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _panDelta = Offset.zero,
          onPanUpdate: (details) {
            _panDelta += details.delta;
            setState(() {
              _pos = _clamp(pos + details.delta, size);
            });
          },
          onPanEnd: (_) {
            if (_panDelta.distance < 10) {
              context.push('/qr');
            } else if (_pos != null) {
              _savePos(_pos!);
            }
          },
          child: const KitschQrFab(),
        ),
      ),
    );
  }
}

class KitschQrPainter extends CustomPainter {
  KitschQrPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final f = Paint()..color = ink;

    canvas.drawRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), p);

    void corner(double x, double y, double s) {
      canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
      canvas.drawRect(
        Rect.fromLTWH(x + s * 0.28, y + s * 0.28, s * 0.44, s * 0.44),
        f,
      );
    }

    final s = size.width * 0.28;
    corner(3, 3, s);
    corner(size.width - 3 - s, 3, s);
    corner(3, size.height - 3 - s, s);

    final d = size.width * 0.1;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.62, size.height * 0.62),
        width: d,
        height: d,
      ),
      f,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.48),
        width: d,
        height: d,
      ),
      f,
    );
  }

  @override
  bool shouldRepaint(covariant KitschQrPainter oldDelegate) =>
      oldDelegate.ink != ink;
}
