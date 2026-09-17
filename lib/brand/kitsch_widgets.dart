import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Candy wash + Ben-Day dots + optional checker strip  -  kitsch paper.
class KitschBackdrop extends StatelessWidget {
  const KitschBackdrop({
    super.key,
    required this.child,
    this.dotColor,
    this.wash,
  });

  final Widget child;
  final Color? dotColor;
  final Color? wash;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = wash ?? Theme.of(context).scaffoldBackgroundColor;
    final ink = dotColor ?? scheme.primary.withValues(alpha: 0.22);

    return ColoredBox(
      color: bg,
      child: CustomPaint(
        painter: _HalftonePainter(color: ink, accent: scheme.secondary),
        child: child,
      ),
    );
  }
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color;
    const step = 18.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final odd = ((x / step).floor() + (y / step).floor()).isOdd;
        canvas.drawCircle(
          Offset(x, y),
          odd ? 2.4 : 1.4,
          odd ? (Paint()..color = accent.withValues(alpha: 0.14)) : dot,
        );
      }
    }

    // Retro diagonal stripe band at top  -  like a bazaar banner scrap.
    final stripe = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    for (var i = -40.0; i < size.width + 80; i += 22) {
      canvas.drawLine(Offset(i, 0), Offset(i + 90, 70), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

/// Die-cut sticker panel with thick ink + hard offset shadow.
class KitschSticker extends StatelessWidget {
  const KitschSticker({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.tilt = 0,
    this.onTap,
    this.borderWidth = 3.5,
    this.radius = 18,
    this.shadowDx = 5,
    this.shadowDy = 5,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double tilt;
  final VoidCallback? onTap;
  final double borderWidth;
  final double radius;
  final double shadowDx;
  final double shadowDy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.outline;
    final fill = color ?? scheme.surface;

    Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ink, width: borderWidth),
        boxShadow: kitschOffsetShadow(
          ink: ink,
          dx: shadowDx,
          dy: shadowDy,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fill,
            Color.lerp(fill, scheme.tertiary, 0.18)!,
          ],
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      panel = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: panel,
        ),
      );
    }

    if (tilt == 0) return panel;
    return Transform.rotate(angle: tilt * math.pi / 180, child: panel);
  }
}

/// Starburst / “NEW!!!” badge  -  pure kitsch ornament.
class KitschBurstBadge extends StatelessWidget {
  const KitschBurstBadge({
    super.key,
    required this.label,
    this.fill,
  });

  final String label;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = fill ?? scheme.tertiary;
    return CustomPaint(
      painter: _BurstPainter(fill: bg, ink: scheme.outline),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.fill, required this.ink});

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.max(size.width, size.height) / 2 + 6;
    final path = Path();
    const spikes = 12;
    for (var i = 0; i < spikes * 2; i++) {
      final angle = (i / (spikes * 2)) * math.pi * 2 - math.pi / 2;
      final rad = i.isEven ? r : r * 0.72;
      final x = cx + math.cos(angle) * rad;
      final y = cy + math.sin(angle) * rad;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.ink != ink;
}

/// Glossy plastic ribbon strip for section titles.
class KitschRibbon extends StatelessWidget {
  const KitschRibbon({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.secondary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.rotate(
        angle: -0.04,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outline, width: 3),
            boxShadow: kitschOffsetShadow(ink: scheme.outline, dx: 3, dy: 3),
          ),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.6,
                  color: scheme.onSecondary,
                ),
          ),
        ),
      ),
    );
  }
}
