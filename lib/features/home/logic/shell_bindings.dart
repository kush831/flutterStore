import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/shell_data.dart';
import '../../../core/storage/storage_providers.dart';
import 'dashboard_controller.dart';

/// Replaces the placeholder providers of the app frame (sidebar / rail / top bar) with real data.
final shellOverrides = [
  shellHeaderProvider.overrideWith((ref) {
    final d = ref.watch(dashboardProvider);
    final name = d.home.value?.storeName ?? '';
    return ShellHeader(
      name: name.isEmpty ? AppEnv.appName : name,
      imageUrl: d.home.value?.profileImage,
      isOpen: d.isOpen,
      updating: d.updating,
    );
  }),
  storeStatusToggleProvider.overrideWith((ref) => (open) => ref.read(dashboardProvider.notifier).toggleOpen(open)),
  isFoodStoreProvider.overrideWith((ref) => ref.watch(appPrefsProvider).isFood),
];