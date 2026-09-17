import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/tenant.dart';
import 'auth_state.dart';

const _kOwnerId = 'sksnacks_owner_id';
const _kOwnerName = 'sksnacks_owner_name';
const _kOwnerEmail = 'sksnacks_owner_email';
const _kPlatform = 'sksnacks_is_platform';
const _kRole = 'sksnacks_role';
const _kForcedSyncDone = 'sksnacks_cutover_forced_sync_v1';

/// Call from main() before runApp.
Future<AuthSession?> loadPersistedOwner() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getString(_kOwnerId);
  final name = prefs.getString(_kOwnerName);
  if (id == null || name == null) return null;
  final email = prefs.getString(_kOwnerEmail);
  final platform = prefs.getBool(_kPlatform) ?? false;
  final roleName = prefs.getString(_kRole) ?? ShopRole.primary.name;
  final role = ShopRole.values.firstWhere(
    (r) => r.name == roleName,
    orElse: () => ShopRole.primary,
  );
  return AuthSession(
    ownerId: id,
    displayName: name,
    email: email,
    isPlatformAdmin: platform,
    role: platform ? ShopRole.platform : role,
  );
}

Future<bool> cutoverForcedSyncPending() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kForcedSyncDone) ?? false);
}

Future<void> markCutoverForcedSyncDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kForcedSyncDone, true);
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(scopes: const ['email', 'profile']);
});

final authInitialSessionProvider = Provider<AuthSession?>((ref) => null);

class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => ref.read(authInitialSessionProvider);

  Future<String?> signInWithGoogle() async {
    final auth = ref.read(firebaseAuthProvider);
    final googleSignIn = ref.read(googleSignInProvider);
    try {
      final account = await googleSignIn.signIn();
      if (account == null) return 'Sign-in cancelled';
      final ga = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: ga.accessToken,
        idToken: ga.idToken,
      );
      final cred = await auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) return 'No Firebase user';
      final email = user.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) {
        await auth.signOut();
        await googleSignIn.signOut();
        return 'Google account has no email';
      }

      final platform = isPlatformAdminEmail(email);
      ShopRole role = ShopRole.primary;
      if (!platform) {
        final gate = await _resolveShopSeat(user, email);
        if (gate.error != null) {
          await auth.signOut();
          await googleSignIn.signOut();
          return gate.error;
        }
        role = gate.role;
      }

      final session = sessionFromFirebaseUser(
        user,
        platformAdmin: platform,
        role: role,
      );
      await _persist(session);
      state = session;
      return null;
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      return '$e';
    }
  }

  Future<({ShopRole role, String? error})> _resolveShopSeat(
    User user,
    String email,
  ) async {
    final db = FirebaseFirestore.instance;
    final profileRef = shopProfileRef(db);
    final ownersCol = shopCollectionRef('owners', db);

    try {
      final profile = await profileRef.get();
      final data = profile.data() ?? {};
      final claimLocked = data['ownerClaimLocked'] == true;
      final primaryEmail =
          (data['primaryEmail'] as String?)?.trim().toLowerCase();

      if (primaryEmail != null && primaryEmail == email) {
        await ownersCol.doc(user.uid).set({
          'email': email,
          'role': 'primary',
          'displayName': user.displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return (role: ShopRole.primary, error: null);
      }

      final secondariesSnap = await ownersCol
          .where('role', isEqualTo: 'secondary')
          .limit(5)
          .get();
      for (final doc in secondariesSnap.docs) {
        final e = (doc.data()['email'] as String?)?.trim().toLowerCase();
        if (e == email) {
          if (doc.data()['blocked'] == true) {
            return (role: ShopRole.secondary, error: 'This account is blocked');
          }
          await ownersCol.doc(user.uid).set({
            'email': email,
            'role': 'secondary',
            'displayName': user.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return (role: ShopRole.secondary, error: null);
        }
      }

      final byEmail = await ownersCol.doc(email).get();
      if (byEmail.exists) {
        final d = byEmail.data()!;
        if (d['role'] == 'secondary' && d['blocked'] != true) {
          await ownersCol.doc(user.uid).set({
            ...d,
            'email': email,
            'role': 'secondary',
            'displayName': user.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return (role: ShopRole.secondary, error: null);
        }
      }

      if (!claimLocked && (primaryEmail == null || primaryEmail.isEmpty)) {
        await profileRef.set({
          'shopId': kShopId,
          'brandId': kShopId,
          'primaryEmail': email,
          'primaryUid': user.uid,
          'ownerClaimLocked': true,
          'pilotStartedAt':
              data['pilotStartedAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await ownersCol.doc(user.uid).set({
          'email': email,
          'role': 'primary',
          'displayName': user.displayName,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _ensureDefaultFeatures(db);
        return (role: ShopRole.primary, error: null);
      }

      return (
        role: ShopRole.primary,
        error: 'Not authorized for this shop. Ask the owner to add your email.',
      );
    } catch (e) {
      debugPrint('Seat resolve failed: $e');
      return (role: ShopRole.primary, error: null);
    }
  }

  Future<void> _ensureDefaultFeatures(FirebaseFirestore db) async {
    const keys = [
      'inventory',
      'invoices',
      'credit',
      'factory',
      'qr',
      'barcodeDraft',
      'voice',
      'dayCash',
      'importExport',
      'cloudSync',
      'cloudBackup',
      'multiSeat',
      'profitView',
      'customerEyeview',
      'customAttributes',
      'removeBaithakFooter',
    ];
    final batch = db.batch();
    final base = shopCollectionRef('features', db);
    for (final k in keys) {
      batch.set(base.doc(k), {
        'enabled': true,
        'source': 'pilot',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _persist(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOwnerId, session.ownerId);
    await prefs.setString(_kOwnerName, session.displayName);
    if (session.email != null) {
      await prefs.setString(_kOwnerEmail, session.email!);
    }
    await prefs.setBool(_kPlatform, session.isPlatformAdmin);
    await prefs.setString(_kRole, session.role.name);
  }

  Future<void> signOut() async {
    try {
      await ref.read(googleSignInProvider).signOut();
    } catch (_) {}
    try {
      await ref.read(firebaseAuthProvider).signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOwnerId);
    await prefs.remove(_kOwnerName);
    await prefs.remove(_kOwnerEmail);
    await prefs.remove(_kPlatform);
    await prefs.remove(_kRole);
    state = null;
  }

  Future<String?> addSecondaryEmail(String rawEmail) async {
    final session = state;
    if (session == null) return 'Not signed in';
    if (!session.isPlatformAdmin && session.role != ShopRole.primary) {
      return 'Only primary owner can add users';
    }
    final email = rawEmail.trim().toLowerCase();
    if (!email.contains('@')) return 'Invalid email';
    if (isPlatformAdminEmail(email)) return 'That email is reserved';

    final col = shopCollectionRef('owners');
    final existing = await col.where('role', isEqualTo: 'secondary').get();
    final emails = existing.docs
        .map((d) => (d.data()['email'] as String?)?.toLowerCase())
        .whereType<String>()
        .toSet();
    if (emails.contains(email)) return null;
    if (emails.length >= 2) return 'Max 2 secondary users';

    await col.doc(email).set({
      'email': email,
      'role': 'secondary',
      'blocked': false,
      'addedBy': session.email,
      'silent': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return null;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthSession?>(AuthController.new);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider) != null;
});

final isPlatformAdminProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider)?.isPlatformAdmin ?? false;
});
