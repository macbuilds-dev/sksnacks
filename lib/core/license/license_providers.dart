import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/tenant.dart';
import '../../features/auth/auth_providers.dart';

const _kPilotStartedMs = 'sksnacks_pilot_started_ms';

/// L1 Spark-safe: evaluate on app open / login. Month 1 = all features on.
class LicenseSnapshot {
  const LicenseSnapshot({
    required this.pilotStartedAt,
    required this.inPilotMonth,
    required this.features,
  });

  final DateTime? pilotStartedAt;
  final bool inPilotMonth;
  final Map<String, bool> features;

  bool isEnabled(String key) {
    if (inPilotMonth) return true;
    return features[key] ?? false;
  }
}

final licenseSnapshotProvider = FutureProvider<LicenseSnapshot>((ref) async {
  final session = ref.watch(authControllerProvider);
  if (session?.bypassFeatureLocks == true) {
    return LicenseSnapshot(
      pilotStartedAt: DateTime.now(),
      inPilotMonth: true,
      features: const {},
    );
  }

  final prefs = await SharedPreferences.getInstance();
  var startedMs = prefs.getInt(_kPilotStartedMs);
  if (startedMs == null) {
    startedMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_kPilotStartedMs, startedMs);
    try {
      await shopProfileRef().set({
        'pilotStartedAt': FieldValue.serverTimestamp(),
        'shopId': kShopId,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
  final inPilot = DateTime.now().difference(started).inDays < 30;

  final features = <String, bool>{};
  try {
    final snap = await shopCollectionRef('features').get();
    for (final d in snap.docs) {
      final enabled = d.data()['enabled'] == true;
      final exp = d.data()['expiresAt'];
      var ok = enabled;
      if (exp is Timestamp) {
        ok = ok && exp.toDate().isAfter(DateTime.now());
      }
      features[d.id] = ok;
    }
  } catch (_) {}

  return LicenseSnapshot(
    pilotStartedAt: started,
    inPilotMonth: inPilot,
    features: features,
  );
});
