import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../storage/storage_providers.dart';
import 'design_tokens.dart';

/// Overridden in main() with the real instance.

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => switch (ref.read(sharedPreferencesProvider).getString(_key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  /// [current] = the brightness the user is looking at right now.
  void toggle(Brightness current) => set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
/// After a Preview PIN the merchant's brand colour is used (Jetpack did the same). false = keep the env colour.
const kUsePreviewPrimaryColor = true;

class PrimaryColorController extends Notifier<Color> {
  @override
  Color build() {
    if (kUsePreviewPrimaryColor && AppEnv.isPreview) {
      final saved = AppEnv.parseColor(ref.read(appPrefsProvider).previewPrimaryColor);
      if (saved != null) return saved;
    }
    return AppEnv.primary;
  }

  void set(Color c) => state = c;
}
final primaryColorProvider = NotifierProvider<PrimaryColorController, Color>(PrimaryColorController.new);

/// Sun / moon button. Used in the desktop top bar and on phone pages.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    return Tooltip(
      message: dark ? 'Switch to light theme' : 'Switch to dark theme',
      child: IconButton(
        onPressed: () => ref.read(themeModeProvider.notifier).toggle(Theme.of(context).brightness),
        icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: context.tk.text2),
      ),
    );
  }
}