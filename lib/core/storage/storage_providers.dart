import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_prefs.dart';
import 'session_store.dart';

/// Overridden in main() with real instances (loaded before runApp).
final sharedPreferencesProvider = Provider<SharedPreferences>(
      (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

final sessionStoreProvider = Provider<SessionStore>(
      (ref) => throw UnimplementedError('Override sessionStoreProvider in main()'),
);

final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs(ref.watch(sharedPreferencesProvider)));