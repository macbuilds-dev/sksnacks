import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand/app_theme.dart';
import 'brand/brand_providers.dart';
import 'brand/kitsch_widgets.dart';
import 'core/routing/app_router.dart';

class SkSnacksApp extends ConsumerWidget {
  const SkSnacksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandAsync = ref.watch(brandConfigProvider);
    final router = ref.watch(routerProvider);

    return brandAsync.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: KitschBackdrop(
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF2D95)),
            ),
          ),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Brand error: $e'))),
      ),
      data: (brand) => MaterialApp.router(
        title: brand.displayName,
        debugShowCheckedModeBanner: false,
        theme: buildBrandTheme(brand),
        themeAnimationDuration: Duration.zero,
        routerConfig: router,
      ),
    );
  }
}
