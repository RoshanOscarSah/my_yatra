import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/offline_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.initFirebase();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: const MyYatraApp(),
    ),
  );
}
