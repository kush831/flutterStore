import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/signup_repository.dart';
import 'signup_validation.dart';

@immutable
class SignupState {
  const SignupState({this.busy = false, this.errors = const {}, this.banner});

  final bool busy;
  final Map<SignupField, String> errors;

  /// A server refusal ("email already registered") or a connection error, above the button.
  final String? banner;
}

class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  /// Called while typing: that field's error disappears.
  void clearError(SignupField f) {
    if (state.errors.containsKey(f) || state.banner != null) {
      state = SignupState(busy: state.busy, errors: {...state.errors}..remove(f));
    }
  }

  Future<({bool ok, String message})> submit(
      SignupForm form, {
        required bool sponsor,
        required bool termsRequired,
      }) async {
    if (state.busy) return (ok: false, message: '');
    final s = ref.read(stringsProvider);

    final keys = validateSignup(form, sponsorRequired: sponsor, termsRequired: termsRequired);
    if (keys.isNotEmpty) {
      state = SignupState(errors: {for (final e in keys.entries) e.key: s.get(e.value)});
      return (ok: false, message: '');
    }

    state = const SignupState(busy: true);
    try {
      final message = await ref.read(signupRepositoryProvider).signup(form, sponsor: sponsor);
      state = const SignupState();
      return (ok: true, message: message);
    } catch (e) {
      state = SignupState(banner: errorText(e, ref.read(stringsProvider)));
      return (ok: false, message: '');
    }
  }
}

final signupControllerProvider = NotifierProvider.autoDispose<SignupController, SignupState>(SignupController.new);