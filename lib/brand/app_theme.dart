import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand_config.dart';

Color hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

List<BoxShadow> kitschOffsetShadow({
  Color? ink,
  double dx = 5,
  double dy = 5,
}) {
  return [
    BoxShadow(
      color: ink ?? const Color(0xFF11080C),
      offset: Offset(dx, dy),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
}

ThemeData buildBrandTheme(BrandConfig brand) {
  final t = brand.theme;
  final primary = hexColor(t.primary);
  final secondary = hexColor(t.secondary);
  final accent = hexColor(t.accent);
  final background = hexColor(t.background);
  final surface = hexColor(t.surface);
  final onBg = hexColor(t.onBackground);
  final onPrimary = hexColor(t.onPrimary);
  final ink = hexColor(t.outline);

  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: hexColor(t.onSecondary),
    tertiary: accent,
    onTertiary: onBg,
    error: hexColor(t.error),
    onError: Colors.white,
    surface: surface,
    onSurface: hexColor(t.onSurface),
    outline: ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
  );

  final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: onBg,
    displayColor: onBg,
  ).copyWith(
    displayLarge: GoogleFonts.bangers(fontSize: 56, color: onBg, letterSpacing: 1.2),
    displayMedium: GoogleFonts.bangers(fontSize: 44, color: onBg, letterSpacing: 1.2),
    displaySmall: GoogleFonts.bangers(fontSize: 36, color: onBg, letterSpacing: 1.2),
    headlineLarge: GoogleFonts.fredoka(fontSize: 30, fontWeight: FontWeight.w700, color: onBg),
    headlineMedium: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: onBg),
    headlineSmall: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w700, color: onBg),
    titleLarge: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w700, color: onBg),
    titleMedium: GoogleFonts.fredoka(fontSize: 17, fontWeight: FontWeight.w700, color: onBg),
    titleSmall: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.w700, color: onBg),
    labelLarge: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.w700, color: onBg),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: onPrimary, size: 26),
      actionsIconTheme: IconThemeData(color: onPrimary, size: 26),
      titleTextStyle: GoogleFonts.bangers(
        fontSize: 26,
        color: onPrimary,
        letterSpacing: 1.2,
      ),
      shape: Border(bottom: BorderSide(color: ink, width: 4)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: onBg,
      textColor: onBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      titleTextStyle: GoogleFonts.fredoka(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: onBg,
      ),
      subtitleTextStyle: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onBg.withValues(alpha: 0.75),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: GoogleFonts.nunito(color: onBg, fontWeight: FontWeight.w600),
      floatingLabelStyle:
          GoogleFonts.nunito(color: primary, fontWeight: FontWeight.w700),
      hintStyle: GoogleFonts.nunito(color: onBg.withValues(alpha: 0.5)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink, width: 2.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink, width: 2.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 3),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink, width: 3.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink, width: 3.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: accent,
      selectedColor: secondary,
      labelStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w700, color: onBg),
      side: BorderSide(color: ink, width: 2.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onBg,
        elevation: 0,
        animationDuration: Duration.zero,
        textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w800, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ink, width: 3.5),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: onBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink, width: 3.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: accent,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.w700, color: onBg),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: onBg)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: onPrimary,
      unselectedLabelColor: onPrimary.withValues(alpha: 0.7),
      indicatorColor: accent,
      labelStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
    ),
    dividerColor: ink.withValues(alpha: 0.35),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      circularTrackColor: accent.withValues(alpha: 0.35),
    ),
  );
}
