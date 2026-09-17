import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thick square-cap icons that match the kitsch back arrow (not Material vectors).
class KitschNavIcon extends StatelessWidget {
  const KitschNavIcon({
    super.key,
    required this.kind,
    this.size = 24,
    this.stroke = 3.0,
    this.color,
  });

  final KitschNavKind kind;
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.outline;
    return CustomPaint(
      size: Size.square(size),
      painter: _KitschNavPainter(kind: kind, ink: ink, stroke: stroke),
    );
  }
}

enum KitschNavKind { home, stock, khata, factory, more }

class _KitschNavPainter extends CustomPainter {
  _KitschNavPainter({
    required this.kind,
    required this.ink,
    required this.stroke,
  });

  final KitschNavKind kind;
  final Color ink;
  final double stroke;

  Paint get _stroke => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.square
    ..strokeJoin = StrokeJoin.miter;

  Paint get _fill => Paint()
    ..color = ink
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case KitschNavKind.home:
        _home(canvas, size);
      case KitschNavKind.stock:
        _stock(canvas, size);
      case KitschNavKind.khata:
        _khata(canvas, size);
      case KitschNavKind.factory:
        _factory(canvas, size);
      case KitschNavKind.more:
        _more(canvas, size);
    }
  }

  void _home(Canvas canvas, Size size) {
    final p = _stroke;
    // Overview dashboard: 2x2 info panels
    final gap = size.width * 0.08;
    final cellW = (size.width - gap * 3) / 2;
    final cellH = (size.height - gap * 3) / 2;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final left = gap + col * (cellW + gap);
        final top = gap + row * (cellH + gap);
        canvas.drawRect(Rect.fromLTWH(left, top, cellW, cellH), p);
      }
    }
    // Pulse / center mark
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.07,
      _fill,
    );
  }

  void _stock(Canvas canvas, Size size) {
    final p = _stroke;
    // Crate / box
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.18,
        size.height * 0.32,
        size.width * 0.82,
        size.height * 0.86,
      ),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.5),
      Offset(size.width * 0.82, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.86),
      p,
    );
    // Lid flap
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.14),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.14),
      p,
    );
  }

  void _khata(Canvas canvas, Size size) {
    final p = _stroke;
    // Notepad / pad
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.18,
          size.height * 0.12,
          size.width * 0.72,
          size.height * 0.88,
        ),
        const Radius.circular(2),
      ),
      p,
    );
    // Binding rings
    for (final y in [0.28, 0.42, 0.56]) {
      canvas.drawLine(
        Offset(size.width * 0.12, size.height * y),
        Offset(size.width * 0.18, size.height * y),
        p,
      );
    }
    // Ruled lines
    for (final y in [0.38, 0.52, 0.66]) {
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * y),
        Offset(size.width * 0.62, size.height * y),
        p,
      );
    }
    // Pencil
    final pencil = Path()
      ..moveTo(size.width * 0.62, size.height * 0.78)
      ..lineTo(size.width * 0.88, size.height * 0.22)
      ..lineTo(size.width * 0.94, size.height * 0.28)
      ..lineTo(size.width * 0.68, size.height * 0.84)
      ..close();
    canvas.drawPath(pencil, p);
    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.22),
      Offset(size.width * 0.92, size.height * 0.18),
      p,
    );
  }

  void _factory(Canvas canvas, Size size) {
    final p = _stroke;
    // Gear — kaarkhana / factory
    final c = Offset(size.width * 0.5, size.height * 0.52);
    final outer = size.width * 0.28;
    final inner = size.width * 0.12;
    canvas.drawCircle(c, outer, p);
    canvas.drawCircle(c, inner, p);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final cosA = math.cos(a);
      final sinA = math.sin(a);
      final tooth = Path()
        ..moveTo(c.dx + cosA * outer * 0.92, c.dy + sinA * outer * 0.92)
        ..lineTo(c.dx + cosA * outer * 1.32, c.dy + sinA * outer * 1.32)
        ..lineTo(
          c.dx + math.cos(a + 0.22) * outer * 1.32,
          c.dy + math.sin(a + 0.22) * outer * 1.32,
        )
        ..lineTo(
          c.dx + math.cos(a + 0.22) * outer * 0.92,
          c.dy + math.sin(a + 0.22) * outer * 0.92,
        )
        ..close();
      canvas.drawPath(tooth, p);
    }
  }

  void _more(Canvas canvas, Size size) {
    final f = _fill;
    final r = size.width * 0.09;
    for (final cx in [0.28, 0.5, 0.72]) {
      for (final cy in [0.28, 0.5, 0.72]) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width * cx, size.height * cy),
            width: r * 2,
            height: r * 2,
          ),
          f,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KitschNavPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.ink != ink ||
      oldDelegate.stroke != stroke;
}
