import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';

/// What the shell shows about the store (name, logo, open/closed).
class ShellHeader {
  const ShellHeader({this.name = '', this.imageUrl, this.isOpen, this.updating = false});

  final String name;
  final String? imageUrl;

  /// null = unknown / not loaded → the status switch is hidden.
  final bool? isOpen;
  final bool updating;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final s = words.map((w) => w[0].toUpperCase()).join();
    return s.isEmpty ? '·' : s;
  }
}

/// Overridden in Step 13 / 20 from the store profile and dashboard.
final shellHeaderProvider = Provider<ShellHeader>((ref) => const ShellHeader(name: AppEnv.appName));

/// Toggles store open/closed. Returns an error message or null. null provider = no toggle.
final storeStatusToggleProvider = Provider<Future<String?> Function(bool open)?>((ref) => null);

/// Options / Categories-with-options are for food stores only. Overridden in Step 13.
final isFoodStoreProvider = Provider<bool>((ref) => true);