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

class DefaultFirebaseOptions {
  static const bool isDemo = true;

  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:000000000000:web:0000000000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-myyatra',
        storageBucket: 'demo-myyatra.appspot.com',
        authDomain: 'demo-myyatra.firebaseapp.com',
        iosBundleId: 'com.yatracrew.myYatra',
      );
}
