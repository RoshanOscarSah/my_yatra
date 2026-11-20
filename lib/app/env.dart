import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// App-wide configuration values.
class Env {
  /// Use the local Firebase Emulator Suite (default while firebase_options.dart
  /// is the demo placeholder). Override with --dart-define=USE_EMULATOR=false.
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR',
      defaultValue: DefaultFirebaseOptions.isDemo);

  /// Host of the emulators. Android emulators reach the host machine at
  /// 10.0.2.2; override with --dart-define=EMULATOR_HOST=192.168.x.x for a
  /// physical phone.
  static String get emulatorHost {
    const fromEnv = String.fromEnvironment('EMULATOR_HOST');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  /// NFR (US-1.4): sign out after this long without any interaction.
  static const idleTimeout = Duration(minutes: 15);

  /// US-7.2: allowed photo size and types.
  static const maxPhotoBytes = 10 * 1024 * 1024;
  static const maxPhotosPerEntry = 6;
  static const allowedPhotoTypes = ['jpg', 'jpeg', 'png', 'webp', 'heic'];

  static Future<void> initFirebase() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Offline cache so saved data stays readable without signal (US-11.2).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    if (useEmulator) {
      final host = emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
  }
}
