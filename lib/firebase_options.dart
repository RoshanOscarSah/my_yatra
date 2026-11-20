// PLACEHOLDER Firebase options for the local Firebase Emulator Suite.
//
// The project id starts with "demo-", which tells the emulators that no real
// Firebase project is involved. To connect a real project, run:
//
//   flutterfire configure --project=<your-firebase-project-id>
//
// That command overwrites this file. Then run the app with
// --dart-define=USE_EMULATOR=false (see README.md).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static const bool isDemo = true;

  // The native iOS/Android SDKs reject an app id whose platform segment
  // does not match, so each platform gets a well-formed placeholder.
  static String get _appId {
    if (kIsWeb) return '1:000000000000:web:0000000000000000000000';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        '1:000000000000:ios:0000000000000000000000',
      _ => '1:000000000000:android:0000000000000000000000',
    };
  }

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: _appId,
        messagingSenderId: '000000000000',
        projectId: 'demo-myyatra',
        storageBucket: 'demo-myyatra.appspot.com',
        authDomain: 'demo-myyatra.firebaseapp.com',
        iosBundleId: 'com.yatracrew.myYatra',
      );
}
