import 'package:firebase_auth/firebase_auth.dart';

class AuthSession {
  const AuthSession({
    required this.ownerId,
    required this.displayName,
    this.email,
    this.isPlatformAdmin = false,
    this.role = ShopRole.primary,
  });

  final String ownerId;
  final String displayName;
  final String? email;
  final bool isPlatformAdmin;
  final ShopRole role;

  bool get canForceSync => isPlatformAdmin;
  bool get bypassFeatureLocks => isPlatformAdmin;
}

enum ShopRole {
  /// First Google owner for this shop.
  primary,

  /// Allowlisted secondary (max 2).
  secondary,

  /// Silent platform operator.
  platform,
}

/// Legacy tap-name presets — kept only for receipt label fallback / migration.
const ownerPresets = <AuthSession>[
  AuthSession(ownerId: 'sadam', displayName: 'Sadam'),
  AuthSession(ownerId: 'usama', displayName: 'Usama'),
  AuthSession(ownerId: 'father', displayName: 'Father'),
];

AuthSession sessionFromFirebaseUser(
  User user, {
  required bool platformAdmin,
  ShopRole role = ShopRole.primary,
}) {
  final email = user.email;
  final name = user.displayName?.trim().isNotEmpty == true
      ? user.displayName!.trim()
      : (email ?? 'Owner');
  return AuthSession(
    ownerId: user.uid,
    displayName: platformAdmin ? 'Baithak' : name,
    email: email,
    isPlatformAdmin: platformAdmin,
    role: platformAdmin ? ShopRole.platform : role,
  );
}
