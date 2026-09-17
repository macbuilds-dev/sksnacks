import 'package:cloud_firestore/cloud_firestore.dart';

/// SHSnacks shop id inside shared Baithak Firebase.
const String kShopId = 'sksnacks';

/// @Deprecated — use [kShopId]
const String kBrandId = kShopId;

/// Platform admins (silent). Email allowlist only.
const kPlatformAdminEmails = <String>{
  'muhammadammarchaudhry1@gmail.com',
  'ammarchaudhry1122@gmail.com',
  'ammarchaudhry23@gmail.com',
};

bool isPlatformAdminEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  return kPlatformAdminEmails.contains(email.trim().toLowerCase());
}

/// `baithak/shops/shop/{shopId}` document — subcollections hang here.
DocumentReference<Map<String, dynamic>> shopRootDoc([
  FirebaseFirestore? db,
]) {
  return (db ?? FirebaseFirestore.instance)
      .collection('baithak')
      .doc('shops')
      .collection('shop')
      .doc(kShopId);
}

CollectionReference<Map<String, dynamic>> shopCollectionRef(
  String name, [
  FirebaseFirestore? db,
]) {
  return shopRootDoc(db).collection(name);
}

/// Profile doc path helper for Auth seat claim.
DocumentReference<Map<String, dynamic>> shopProfileRef([
  FirebaseFirestore? db,
]) =>
    shopRootDoc(db).collection('settings').doc('profile');

/// String path for logging / rules docs.
String get shopDocPath => 'baithak/shops/shop/$kShopId';

String shopCollectionPath(String name) => '$shopDocPath/$name';

/// Prefer [shopCollectionRef] for queries. String kept for meta maps.
String tenantCollection(String name) => shopCollectionPath(name);

String tenantCollectionLegacyRoot(String name) => '${kShopId}_$name';

String tenantCollectionLegacyNested(String name) => 'tenants/$kShopId/$name';

String tenantCollectionLegacy(String name) => tenantCollectionLegacyRoot(name);

String tenantStoragePath(String name) => 'baithak/shops/$kShopId/$name';

String get tenantMetaDocPath => '$shopDocPath/settings/profile';

String get shopOwnersPath => '$shopDocPath/owners';

String get shopFeaturesPath => '$shopDocPath/features';

String get shopCommandsPath => '$shopDocPath/commands';

String get platformAdminsPath => 'baithak/platform_admins/emails';
