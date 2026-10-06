import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../network/session_events.dart';
import '../storage/storage_providers.dart';

@immutable
class AuthState {
  const AuthState({
    this.loggedIn = false,
    this.signupStatus = 0,
    this.notice,
    this.returnToAfterLogin = true,
  });

  final bool loggedIn;

  /// 0 = fine · 3 = Stripe documents required · 4 = upload documents required.
  final int signupStatus;

  /// Set when the session ended because the server said so (result 999). The login screen shows it once.
  /// '' = no server text, use the default message.
  final String? notice;

  /// true: after login, go back to the page the user wanted (deep link / expired session).
  /// false: after an explicit sign-out the next user starts fresh.
  final bool returnToAfterLogin;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final sub = ref.read(sessionEventsProvider).expired.listen(_onExpired);
    ref.onDispose(sub.cancel);

    final session = ref.read(sessionStoreProvider);
    final prefs = ref.read(appPrefsProvider);
    return AuthState(loggedIn: session.isLoggedIn, signupStatus: session.isLoggedIn ? prefs.signupStatus : 0);
  }

  /// The API answered `result: "999"`. Many requests can fail together → this runs once (SessionEvents).
  Future<void> _onExpired(String message) async {
    if (!state.loggedIn) {
      ref.read(sessionEventsProvider).reset();
      return;
    }
    await _clearAccount();
    state = AuthState(notice: message); // returnToAfterLogin stays true
  }

  /// Called by the login screens after a successful login.
  Future<void> signIn({
    required String token,
    String? publicKey,
    String? secretKey,
    int signupStatus = 0,
  }) async {
    await ref.read(sessionStoreProvider).saveLogin(token: token, publicKey: publicKey, secretKey: secretKey);
    await ref.read(appPrefsProvider).setSignupStatus(signupStatus);
    ref.read(sessionEventsProvider).reset();
    state = AuthState(loggedIn: true, signupStatus: signupStatus);
  }

  /// Explicit sign-out (More → Logout, after the logout API call).
  Future<void> signOut() async {
    await _clearAccount();
    ref.read(sessionEventsProvider).reset();
    state = const AuthState(returnToAfterLogin: false);
  }

  /// The Stripe / upload documents screens call this with 0 after a successful submit.
  Future<void> setSignupStatus(int status) async {
    await ref.read(appPrefsProvider).setSignupStatus(status);
    state = AuthState(loggedIn: state.loggedIn, signupStatus: status, returnToAfterLogin: state.returnToAfterLogin);
  }

  /// The login screen calls this after showing [AuthState.notice].
  void consumeNotice() {
    if (state.notice == null) return;
    ref.read(sessionEventsProvider).reset();
    state = AuthState(
      loggedIn: state.loggedIn,
      signupStatus: state.signupStatus,
      returnToAfterLogin: state.returnToAfterLogin,
    );
  }

  /// Dev hub only: pretend to be signed in so private pages can be opened.
  Future<void> devSignIn({int signupStatus = 0}) async {
    assert(AppEnv.devTools, 'devSignIn is for development builds');
    if (!AppEnv.devTools) return;
    await signIn(token: 'dev-token', signupStatus: signupStatus);
  }

  Future<void> _clearAccount() async {
    await ref.read(sessionStoreProvider).clear();
    await ref.read(appPrefsProvider).clearAccount();
    ref.read(userScopeProvider.notifier).bump();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The "which store is signed in" counter. It goes up on every sign-out / session expiry.
///
/// CONVENTION for every later step: any provider that holds data of the signed-in store
/// starts with `ref.watch(userScopeProvider);`. Then a sign-out clears it automatically,
/// and the next user can never see the previous user's orders, products or balance.
class UserScope extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final userScopeProvider = NotifierProvider<UserScope, int>(UserScope.new);