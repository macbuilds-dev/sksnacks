import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../brand/app_theme.dart';
import '../../brand/brand_providers.dart';
import '../../brand/kitsch_widgets.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/database_provider.dart';
import '../../features/auth/auth_providers.dart';
import '../../l10n/app_copy.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tick = 0;
  bool _cutoverSyncStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCutoverSync());
  }

  Future<void> _maybeCutoverSync() async {
    if (_cutoverSyncStarted || !mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth == null) return;
    if (!await cutoverForcedSyncPending()) return;
    _cutoverSyncStarted = true;
    if (!mounted) return;
    await runCloudSync(context, ref, forceFullMirror: true);
    await markCutoverForcedSyncDone();
    if (mounted) setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final db = ref.watch(appDatabaseProvider);
    final brand = ref.watch(brandConfigProvider).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return FutureBuilder(
      key: ValueKey(_tick),
      future: Future.wait([
        db.totalStockQty(),
        db.totalStockValue(),
        db.cashNet(),
        db.totalPartyBalance(),
        db.pendingSyncCount(),
      ]),
      builder: (context, snap) {
        final stock = snap.hasData ? snap.data![0] as double : 0.0;
        final stockValue = snap.hasData ? snap.data![1] as double : 0.0;
        final cash = snap.hasData ? snap.data![2] as double : 0.0;
        final credit = snap.hasData ? snap.data![3] as double : 0.0;

        return KitschBackdrop(
          child: RefreshIndicator(
            onRefresh: () async => setState(() => _tick++),
            child: SafeArea(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (brand?.displayName ?? 'SHSnacks').toUpperCase(),
                          style: GoogleFonts.bangers(
                            fontSize: 36,
                            color: scheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      KitschIconButton(
                        icon: Icons.cloud_sync,
                        tooltip: Copy.settingsSync,
                        color: scheme.secondary,
                        onPressed: () async {
                          await runCloudSync(context, ref);
                          if (mounted) setState(() => _tick++);
                        },
                      ),
                      if (auth != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: KitschSticker(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shadowDx: 2,
                            shadowDy: 2,
                            borderWidth: 2.5,
                            color: scheme.tertiary,
                            child: Text(auth.displayName),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${Copy.homeGreeting}, ${Copy.homeGreetingTail}'
                    '${auth != null ? ' · ${auth.displayName}' : ''}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Copy.appTagline,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  _SpineCard(
                    title: Copy.homeStock,
                    subtitle: Copy.homeStockHint,
                    hint: 'INVENTORY',
                    value: '${_fmt(stock)} · Rs ${_fmt(stockValue)}',
                    fill: scheme.secondary,
                    tilt: -1.6,
                    onTap: () => context.go('/stock'),
                  ),
                  const SizedBox(height: 16),
                  _SpineCard(
                    title: Copy.homeCash,
                    subtitle: Copy.homeCashHint,
                    hint: 'CASH DESK',
                    value: 'Rs ${_fmt(cash)}',
                    fill: scheme.tertiary,
                    tilt: 1.4,
                    onTap: () => context.push('/cash'),
                  ),
                  const SizedBox(height: 16),
                  _SpineCard(
                    title: Copy.homeCredit,
                    subtitle: Copy.homeCreditHint,
                    hint: 'KHAATA',
                    value: 'Rs ${_fmt(credit)}',
                    fill: scheme.primary,
                    tilt: -0.9,
                    onTap: () => context.go('/khata'),
                  ),
                  const SizedBox(height: 24),
                  const KitschRibbon(label: Copy.homeQuick),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      _ModuleTile(
                        label: Copy.dayTitle,
                        kind: _QuickKind.day,
                        color: scheme.tertiary,
                        tilt: -3,
                        onTap: () => context.push('/day-check'),
                      ),
                      _ModuleTile(
                        label: Copy.invoiceTitle,
                        kind: _QuickKind.bill,
                        color: const Color(0xFFFF9AD5),
                        tilt: -2,
                        onTap: () => context.push('/invoices'),
                      ),
                      _ModuleTile(
                        label: Copy.customerTitle,
                        kind: _QuickKind.eye,
                        color: const Color(0xFFB8FF9A),
                        tilt: 3.2,
                        onTap: () => context.push('/customer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

class _SpineCard extends StatelessWidget {
  const _SpineCard({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.value,
    required this.fill,
    required this.tilt,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final String value;
  final Color fill;
  final double tilt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return KitschSticker(
      color: fill,
      tilt: tilt,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.outline, width: 2.5),
                  ),
                  child: Text(
                    hint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.bangers(
              fontSize: value.length > 12 ? 22 : 32,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuickKind { day, bill, eye }

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.label,
    required this.kind,
    required this.color,
    required this.tilt,
    required this.onTap,
  });

  final String label;
  final _QuickKind kind;
  final Color color;
  final double tilt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: tilt * 3.14159 / 180,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 156,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline, width: 3.5),
              boxShadow: kitschOffsetShadow(ink: scheme.outline, dx: 4, dy: 4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomPaint(
                  size: const Size(28, 28),
                  painter: _QuickIconPainter(kind: kind, ink: scheme.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickIconPainter extends CustomPainter {
  _QuickIconPainter({required this.kind, required this.ink});

  final _QuickKind kind;
  final Color ink;

  Paint get _s => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.square
    ..strokeJoin = StrokeJoin.miter;

  Paint get _f => Paint()..color = ink;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _QuickKind.day:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 6, size.width - 4, size.height - 8),
            const Radius.circular(3),
          ),
          _s,
        );
        canvas.drawLine(Offset(2, 14), Offset(size.width - 2, 14), _s);
        canvas.drawLine(Offset(10, 2), Offset(10, 10), _s);
        canvas.drawLine(
          Offset(size.width - 10, 2),
          Offset(size.width - 10, 10),
          _s,
        );
        canvas.drawRect(const Rect.fromLTWH(8, 18, 6, 6), _f);
        canvas.drawRect(const Rect.fromLTWH(18, 18, 6, 6), _f);
      case _QuickKind.bill:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(6, 2, size.width - 12, size.height - 4),
            const Radius.circular(2),
          ),
          _s,
        );
        for (final y in [12.0, 18.0, 24.0]) {
          canvas.drawLine(Offset(11, y), Offset(size.width - 11, y), _s);
        }
      case _QuickKind.eye:
        final path = Path()
          ..moveTo(2, size.height * 0.5)
          ..quadraticBezierTo(
            size.width * 0.5,
            4,
            size.width - 2,
            size.height * 0.5,
          )
          ..quadraticBezierTo(
            size.width * 0.5,
            size.height - 4,
            2,
            size.height * 0.5,
          );
        canvas.drawPath(path, _s);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          5,
          _s,
        );
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          2.2,
          _f,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _QuickIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.ink != ink;
}
