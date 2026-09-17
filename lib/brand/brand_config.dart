import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Loaded from `brands/<id>/brand.yaml`  -  theme & flags are swappable without code rewrite.
class BrandConfig {
  BrandConfig({
    required this.id,
    required this.displayName,
    required this.tagline,
    required this.applicationId,
    required this.theme,
    required this.features,
    required this.languages,
  });

  final String id;
  final String displayName;
  final String tagline;
  final String applicationId;
  final BrandThemeColors theme;
  final BrandFeatures features;
  final List<String> languages;

  static Future<BrandConfig> load(String brandId) async {
    final raw = await rootBundle.loadString('brands/$brandId/brand.yaml');
    final map = Map<String, dynamic>.from(loadYaml(raw) as Map);
    final themeMap = Map<String, dynamic>.from(map['theme'] as Map);
    final featuresMap = Map<String, dynamic>.from(map['features'] as Map);
    return BrandConfig(
      id: map['id'] as String,
      displayName: map['displayName'] as String? ?? brandId,
      tagline: map['tagline'] as String? ?? '',
      applicationId: map['applicationId'] as String? ?? '',
      languages: (map['languages'] as List?)?.map((e) => '$e').toList() ??
          const ['en'],
      theme: BrandThemeColors.fromMap(themeMap),
      features: BrandFeatures.fromMap(featuresMap),
    );
  }
}

class BrandThemeColors {
  BrandThemeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
    required this.success,
    required this.warning,
    required this.error,
    required this.outline,
  });

  final String primary;
  final String secondary;
  final String accent;
  final String background;
  final String surface;
  final String onPrimary;
  final String onSecondary;
  final String onBackground;
  final String onSurface;
  final String success;
  final String warning;
  final String error;
  final String outline;

  factory BrandThemeColors.fromMap(Map<String, dynamic> m) => BrandThemeColors(
        primary: m['primary'] as String? ?? '#8B1E3F',
        secondary: m['secondary'] as String? ?? '#0F3D2E',
        accent: m['accent'] as String? ?? '#D4A017',
        background: m['background'] as String? ?? '#F7F0E6',
        surface: m['surface'] as String? ?? '#FFF8F0',
        onPrimary: m['onPrimary'] as String? ?? '#FFF8F0',
        onSecondary: m['onSecondary'] as String? ?? '#F7F0E6',
        onBackground: m['onBackground'] as String? ?? '#2A1810',
        onSurface: m['onSurface'] as String? ?? '#2A1810',
        success: m['success'] as String? ?? '#1B5E3B',
        warning: m['warning'] as String? ?? '#C45C00',
        error: m['error'] as String? ?? '#9B1B1B',
        outline: m['outline'] as String? ?? '#C4A882',
      );
}

class BrandFeatures {
  BrandFeatures({
    required this.factory,
    required this.khata,
    required this.customerEyeview,
    required this.dayCheckInOut,
    required this.invoices,
    required this.qr,
  });

  final bool factory;
  final bool khata;
  final bool customerEyeview;
  final bool dayCheckInOut;
  final bool invoices;
  final bool qr;

  factory BrandFeatures.fromMap(Map<String, dynamic> m) => BrandFeatures(
        factory: m['factory'] as bool? ?? true,
        khata: m['khata'] as bool? ?? true,
        customerEyeview: m['customerEyeview'] as bool? ?? true,
        dayCheckInOut: m['dayCheckInOut'] as bool? ?? true,
        invoices: m['invoices'] as bool? ?? true,
        qr: m['qr'] as bool? ?? true,
      );
}
