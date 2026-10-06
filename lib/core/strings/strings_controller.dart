import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../storage/storage_providers.dart';
import 'app_language.dart';
import 'app_strings.dart';
import 'strings_repository.dart';

class StringsController extends Notifier<AppStrings> {
  final _ready = Completer<void>();
  String? _fetchingFor;

  StringsRepository get _repo => ref.read(stringsRepositoryProvider);

  /// Completes after the first download attempt (success or failure).
  /// The splash screen (Step 6) waits for this, with a short timeout.
  Future<void> get ready => _ready.future;

  @override
  AppStrings build() {
    final prefs = ref.read(appPrefsProvider);
    var lang = AppLanguages.find(prefs.language);
    if (lang == null) {
      lang = AppLanguages.deviceDefault();
      prefs.setLanguage(lang.code); // the `locale` header must always match what the UI shows
    }
    final code = lang.code;
    Intl.defaultLocale = code;

    final cached = _repo.readCache(code);
    Future.microtask(_init);
    return AppStrings(
      code: code,
      strings: cached ?? const {},
      source: cached == null ? StringsSource.none : StringsSource.cache,
    );
  }

  Future<void> _init() async {
    await refresh();
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Downloads the latest strings for the current language. Returns true on success.
  /// A failure keeps whatever is already on screen.
  Future<bool> refresh() async {
    final code = state.code;
    if (_fetchingFor == code) return false;
    _fetchingFor = code;
    try {
      final fresh = await _repo.fetch();
      if (fresh.isEmpty || state.code != code) return false; // empty answer, or the user switched again
      if (!mapEquals(fresh, state.strings)) await _repo.writeCache(code, fresh);
      state = AppStrings(code: code, strings: fresh, source: StringsSource.server);
      return true;
    } catch (e) {
      debugPrint('Strings refresh failed: $e');
      return false;
    } finally {
      if (_fetchingFor == code) _fetchingFor = null;
    }
  }

  /// Switches the whole app to [code].
  ///  • texts already saved → switches at once, refreshes in the background
  ///  • otherwise           → downloads first; on failure the app STAYS on the current language
  /// Returns false when the switch did not happen.
  Future<bool> setLanguage(String code) async {
    if (AppLanguages.find(code) == null) return false;
    if (code == state.code) return true;

    final prefs = ref.read(appPrefsProvider);
    final previous = state.code;
    final cached = _repo.readCache(code);

    await prefs.setLanguage(code); // the next request carries the new `locale` header

    if (cached != null) {
      _commit(code, cached, StringsSource.cache);
      await prefs.setLanguageChosen(true);
      unawaited(refresh());
      return true;
    }

    try {
      final fresh = await _repo.fetch();
      if (fresh.isEmpty) throw StateError('empty strings');
      await _repo.writeCache(code, fresh);
      _commit(code, fresh, StringsSource.server);
      await prefs.setLanguageChosen(true);
      return true;
    } catch (e) {
      debugPrint('Language switch to $code failed: $e');
      await prefs.setLanguage(previous);
      return false;
    }
  }

  void _commit(String code, Map<String, String> strings, StringsSource source) {
    Intl.defaultLocale = code;
    state = AppStrings(code: code, strings: strings, source: source);
  }
}

final stringsProvider = NotifierProvider<StringsController, AppStrings>(StringsController.new);

/// The Flutter Locale (drives RTL, date pickers, number formats).
final localeProvider = Provider<Locale>(
      (ref) => Locale(ref.watch(stringsProvider.select((s) => s.code))),
);