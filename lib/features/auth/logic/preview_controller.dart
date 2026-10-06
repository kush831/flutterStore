import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/theme_controller.dart';
import '../../../core/network/error_text.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../../splash/logic/config_controller.dart';
import '../data/preview_repository.dart';

@immutable
class PreviewState {
  const PreviewState({this.busy = false, this.fieldError, this.banner});

  final bool busy;
  final String? fieldError;
  final String? banner;
}

class PreviewController extends Notifier<PreviewState> {
  @override
  PreviewState build() => const PreviewState();

  void clearErrors() {
    if (state.fieldError != null || state.banner != null) state = PreviewState(busy: state.busy);
  }

  /// true → the screen sends the user to the splash, which restarts everything for this merchant.
  Future<bool> submit(String pin) async {
    if (state.busy) return false;
    final s = ref.read(stringsProvider);
    final p = pin.trim();
    if (p.isEmpty) {
      state = PreviewState(fieldError: s.get('common_formvalidation_required_error'));
      return false;
    }

    state = const PreviewState(busy: true);
    try {
      final m = await ref.read(previewRepositoryProvider).verifyPin(p);

      final prefs = ref.read(appPrefsProvider);
      await ref.read(sessionStoreProvider).saveMerchantKeys(publicKey: m.publicKey, secretKey: m.secretKey);
      await prefs.setEnteredPin(p);
      await prefs.setPreviewPrimaryColor(AppEnv.parseColor(m.primaryColor) == null ? '' : m.primaryColor);
      await prefs.clearConfig(); // belongs to the previous merchant
      await prefs.clearStringsCache();

      state = const PreviewState();
      ref
        ..invalidate(configProvider)
        ..invalidate(stringsProvider)
        ..invalidate(primaryColorProvider);
      return true;
    } catch (e) {
      state = PreviewState(banner: errorText(e, ref.read(stringsProvider)));
      return false;
    }
  }
}

final previewControllerProvider = NotifierProvider.autoDispose<PreviewController, PreviewState>(PreviewController.new);