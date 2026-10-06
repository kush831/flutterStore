import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/password_recovery_repository.dart';

@immutable
class RecoveryState {
  const RecoveryState({this.identifier = '', this.otp = '', this.autoFill = false, this.verified = false});

  final String identifier;
  final String otp; // memory only: never in a URL, never saved
  final bool autoFill;
  final bool verified;
}

/// The recovery flow spans three routes, so this is NOT auto-disposed.
/// A browser refresh clears it, and the screens then send the user back to step 1.
class RecoveryController extends Notifier<RecoveryState> {
  @override
  RecoveryState build() => const RecoveryState();

  PasswordRecoveryRepository get _repo => ref.read(passwordRecoveryRepositoryProvider);

  /// Step 1 (and "Resend"). Throws AppException.
  Future<void> sendCode(String identifier) async {
    final c = await _repo.requestCode(identifier);
    state = RecoveryState(identifier: identifier, otp: c.otp, autoFill: c.autoFill);
  }

  /// Step 2. Today the code is compared here. After the backend fix this becomes
  /// `final token = await _repo.verifyCode(identifier, code)`.
  bool verify(String code) {
    final ok = state.otp.isNotEmpty && code == state.otp;
    if (ok) state = RecoveryState(identifier: state.identifier, otp: state.otp, autoFill: state.autoFill, verified: true);
    return ok;
  }

  /// Step 3. Throws AppException. Returns the server's message and clears the flow.
  Future<String> resetPassword(String password) async {
    if (!state.verified) throw StateError('The code was not verified');
    final message = await _repo.resetPassword(identifier: state.identifier, password: password);
    state = const RecoveryState();
    return message;
  }

  void clear() => state = const RecoveryState();

  @visibleForTesting
  void seed({required String identifier, required String otp}) => state = RecoveryState(identifier: identifier, otp: otp);
}

final recoveryProvider = NotifierProvider<RecoveryController, RecoveryState>(RecoveryController.new);