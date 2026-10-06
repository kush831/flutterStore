import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/router/app_redirect.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/app_config.dart';
import 'config_controller.dart';

const kEnableUpdatePrompt = false;

enum SplashPhase { loading, consent, language, maintenance, update, noData, done }

@immutable
class SplashState {
  const SplashState({
    this.phase = SplashPhase.loading,
    this.message = '',
    this.mandatory = false,
    this.route,
  });

  final SplashPhase phase;
  final String message;
  final bool mandatory;
  final String? route;
}

/// The startup flow as one small state machine. The screen only reacts to the phase.
class SplashController extends Notifier<SplashState> {
  static const _minShow = Duration(milliseconds: 700);

  AppConfig? _cfg;
  final _clock = Stopwatch();

  @override
  SplashState build() {
    Future.microtask(start);
    return const SplashState();
  }

  Future<void> start() async {
    _clock
      ..reset()
      ..start();
    state = const SplashState();

    // 1. texts (cached ones are instant; the first download gets a few seconds)
    final strings = ref.read(stringsProvider.notifier);
    try {
      await strings.ready.timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!ref.read(stringsProvider).isLoaded) await strings.refresh(); // a retry after a failed first download

    // 2. configuration
    final cfg = await ref.read(configProvider.notifier).loadForStartup();

    // Nothing saved and nothing downloaded → the icon-only retry screen (no text exists to show)
    if (cfg == null || !ref.read(stringsProvider).isLoaded) {
      state = const SplashState(phase: SplashPhase.noData);
      return;
    }
    _cfg = cfg;

    // 3. consent (nothing continues before "I Agree")
    if (!ref.read(appPrefsProvider).consentGiven) {
      state = const SplashState(phase: SplashPhase.consent);
      return;
    }
    await _afterConsent();
  }

  Future<void> consentGiven() async {
    await ref.read(appPrefsProvider).setConsentGiven(true);
    await _afterConsent();
  }

  Future<void> _afterConsent() async {
    // 4. first-run language (only when the server offers a choice)
    final prefs = ref.read(appPrefsProvider);
    if (!prefs.languageChosen && (_cfg?.supportedLanguages.length ?? 0) > 1) {
      state = const SplashState(phase: SplashPhase.language);
      return;
    }
    await _gates();
  }

  Future<void> languagePicked() async {
    await ref.read(appPrefsProvider).setLanguageChosen(true);
    await _gates();
  }

  /// 5. maintenance, 6. update
  Future<void> _gates() async {
    final cfg = _cfg;
    if (cfg != null && cfg.maintenance.show) {
      state = SplashState(phase: SplashPhase.maintenance, message: cfg.maintenance.message);
      return;
    }
    if (kEnableUpdatePrompt && !kIsWeb && cfg != null && cfg.update.show) {
      state = SplashState(phase: SplashPhase.update, message: cfg.update.message, mandatory: cfg.update.mandatory);
      return;
    }
    await _route();
  }

  /// "Maybe later" on an optional update.
  Future<void> skipUpdate() => _route();

  /// 7. where to go
  Future<void> _route() async {
    final remaining = _minShow - _clock.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    final auth = ref.read(authControllerProvider);
    final prefs = ref.read(appPrefsProvider);
    state = SplashState(
      phase: SplashPhase.done,
      route: startupRoute(
        loggedIn: auth.loggedIn,
        signupStatus: auth.signupStatus,
        membershipEnabled: auth.loggedIn && prefs.membershipEnabled,
        previewGate: AppEnv.previewPinGate && prefs.enteredPin.isEmpty,
      ),
    );
  }

  AppConfig? get config => _cfg;
}

final splashControllerProvider = NotifierProvider.autoDispose<SplashController, SplashState>(SplashController.new);