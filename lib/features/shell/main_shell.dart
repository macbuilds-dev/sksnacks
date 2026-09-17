import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../brand/app_theme.dart';
import '../../brand/kitsch_nav_icons.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../core/license/feature_gate.dart';
import '../../l10n/app_copy.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = <({KitschNavKind kind, String label, String? feature})>[
    (kind: KitschNavKind.home, label: Copy.navHome, feature: null),
    (kind: KitschNavKind.stock, label: Copy.navStock, feature: 'inventory'),
    (kind: KitschNavKind.khata, label: Copy.navKhata, feature: 'credit'),
    (kind: KitschNavKind.factory, label: Copy.navFactory, feature: 'factory'),
    (kind: KitschNavKind.more, label: Copy.navMore, feature: null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(child: navigationShell),
              DraggableQrFab(
                bounds: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: scheme.outline, width: 4),
            ),
            boxShadow: kitschOffsetShadow(
              ink: scheme.outline,
              dx: 0,
              dy: -3,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _KitschNavTab(
                    kind: _tabs[i].kind,
                    label: _tabs[i].label,
                    selected: i == index,
                    onTap: () async {
                      final feature = _tabs[i].feature;
                      if (feature != null) {
                        final ok =
                            await ensureFeatureOrPrompt(context, ref, feature);
                        if (!ok) return;
                      }
                      navigationShell.goBranch(
                        i,
                        initialLocation: i == index,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KitschNavTab extends StatelessWidget {
  const _KitschNavTab({
    required this.kind,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final KitschNavKind kind;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selected ? scheme.tertiary : scheme.surface;
    final ink = scheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ink, width: selected ? 3 : 2.5),
              boxShadow: selected
                  ? kitschOffsetShadow(ink: ink, dx: 2, dy: 2)
                  : const [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KitschNavIcon(
                  kind: kind,
                  size: 22,
                  stroke: selected ? 3.2 : 2.8,
                  color: ink,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
