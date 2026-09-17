// Generated manually from google-services.json and GoogleService-Info.plist
// Project: baithak-macbuilds-dev
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyByqwQNcEPzjQI4M_OiRE5_V8P69ysU4lY',
    appId: '1:798059988409:android:d5701bd0454b180512a268',
    messagingSenderId: '798059988409',
    projectId: 'baithak-macbuilds-dev',
    storageBucket: 'baithak-macbuilds-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAiQu3TTPhKvt4JcdfFtYJk881UBC7LEhI',
    appId: '1:798059988409:ios:7b199680955cf58612a268',
    messagingSenderId: '798059988409',
    projectId: 'baithak-macbuilds-dev',
    storageBucket: 'baithak-macbuilds-dev.firebasestorage.app',
    iosBundleId: 'com.baithak.sksnacks',
    iosClientId:
        '798059988409-91plpkfiivfri2io9bieqr232fo6vjrr.apps.googleusercontent.com',
  );
}
