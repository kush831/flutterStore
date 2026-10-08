import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/config/app_env.dart';
import '../core/design/design_theme.dart';
import '../core/design/theme_controller.dart';
import '../core/router/app_router.dart';
import '../core/storage/storage_providers.dart';
import '../core/strings/app_language.dart';
import '../core/strings/strings_controller.dart';
import '../core/strings/strings_scope.dart';
import '../features/push/logic/push_service.dart';
import '../features/push/ui/push_banner_host.dart';

/// Mouse and trackpad can drag-scroll (browsers, iPad with a trackpad).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final strings = ref.watch(stringsProvider);

    ref.read(pushServiceProvider).init(); // idempotent
    ref.listen<bool>(authControllerProvider.select((s) => s.loggedIn), (_, loggedIn) {
      final push = ref.read(pushServiceProvider);
      loggedIn ? push.onSignedIn(ref.read(appPrefsProvider).businessSegmentId) : push.onSignedOut();
    });


    return MaterialApp.router(
      title: AppEnv.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: DesignTheme.build(Brightness.light, primary),
      darkTheme: DesignTheme.build(Brightness.dark, primary),
      themeMode: mode,
      scrollBehavior: const AppScrollBehavior(),
      locale: locale, // Arabic → the whole UI turns right-to-left by itself
      supportedLocales: [for (final l in AppLanguages.supported) Locale(l.code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Above the Navigator: pages, dialogs, sheets and snackbars all see the strings.
      builder: (context, child) => StringsScope(
        strings: strings,
        child: PushBannerHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}