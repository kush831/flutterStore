import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_env.dart';
import 'core/storage/session_store.dart';
import 'core/storage/storage_providers.dart';
import 'features/home/logic/shell_bindings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.assertConfigured();

  // Loaded before the first frame, so the network layer never waits on disk.
  final prefs = await SharedPreferences.getInstance();
  final session = await SessionStore.load();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(session),
        // ...shellOverrides
      ],
      child: const App(),
    ),
  );
}