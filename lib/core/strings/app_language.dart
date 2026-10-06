import 'dart:ui';

/// Only the language CODE lives in code. The display names ("English", "Français", "العربية")
/// come from the configuration API in Step 6, like Jetpack's language screen.
class AppLanguage {
  const AppLanguage(this.code, {this.rtl = false});

  final String code; // the value of the `locale` header
  final bool rtl;
}

abstract final class AppLanguages {
  static const supported = <AppLanguage>[
    AppLanguage('en'),
    AppLanguage('fr'),
    AppLanguage('ar', rtl: true),
    AppLanguage('es'),
    AppLanguage('pt'),
    AppLanguage('hi'),
    AppLanguage('sw'),
  ];

  static AppLanguage? find(String? code) {
    if (code == null) return null;
    for (final l in supported) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// The phone's language when we support it, otherwise English.
  static AppLanguage deviceDefault() =>
      find(PlatformDispatcher.instance.locale.languageCode) ?? supported.first;
}