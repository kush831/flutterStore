import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/error_text.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/auth_repository.dart';

@immutable
class LoginState {
  const LoginState({this.busy = false, this.identifierError, this.passwordError, this.banner});

  final bool busy;
  final String? identifierError;
  final String? passwordError;

  /// The server's / connection error shown above the button.
  final String? banner;
}

class LoginController extends Notifier<LoginState> {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  LoginState build() => const LoginState();

  /// Called while typing: errors disappear as soon as the user edits.
  void clearErrors() {
    if (state.identifierError != null || state.passwordError != null || state.banner != null) {
      state = LoginState(busy: state.busy);
    }
  }

  /// Returns true on success. The router then moves the user on (see app_redirect.dart).
  Future<bool> submit({required bool isEmail, required String identifier, required String password}) async {
    if (state.busy) return false;
    final s = ref.read(stringsProvider);
    final id = identifier.trim();

    String? idError;
    if (id.isEmpty) {
      idError = s.get(isEmail ? 'auth_loginscreen_email_required' : 'storedetails_storeprofile_phone_required');
    } else if (isEmail && !_email.hasMatch(id)) {
      idError = s.get('auth_loginscreen_email_invalid');
    }
    final pwError = password.isEmpty ? s.get('auth_loginscreen_password_required') : null;

    if (idError != null || pwError != null) {
      state = LoginState(identifierError: idError, passwordError: pwError);
      return false;
    }

    state = const LoginState(busy: true);
    try {
      final r = await ref.read(authRepositoryProvider).login(identifier: id, password: password);

      final prefs = ref.read(appPrefsProvider);
      await prefs.setSegmentType(r.segment);
      await prefs.setMembershipEnabled(r.membershipNeeded);
      if (r.storeId.isNotEmpty && r.storeId != 'null') await prefs.setBusinessSegmentId(r.storeId);

      state = const LoginState(); // before signing in: the screen is replaced right after
      await ref.read(authControllerProvider.notifier).signIn(token: r.token, signupStatus: r.signupStatus);
      return true;
    } catch (e) {
      if (e is AppException && e.isSession) {
        state = const LoginState();
        return false;
      }
      state = LoginState(banner: errorText(e, ref.read(stringsProvider)));
      return false;
    }
  }
}

final loginControllerProvider = NotifierProvider.autoDispose<LoginController, LoginState>(LoginController.new);