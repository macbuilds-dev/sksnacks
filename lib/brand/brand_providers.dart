import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand_config.dart';

final brandIdProvider = Provider<String>((ref) => 'sksnacks');

final brandConfigProvider = FutureProvider<BrandConfig>((ref) async {
  final id = ref.watch(brandIdProvider);
  return BrandConfig.load(id);
});
