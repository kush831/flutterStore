import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/period_range.dart';
import 'wallet_models.dart';

class WalletRepository {
  WalletRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  String get _locale => _prefs.language ?? 'en';

  /// "All" sends no dates (the ApiClient drops null fields).
  Future<WalletPage> wallet(PeriodRange range, int page) async {
    final root = await _api.postForm(EndPoints.walletTransactions, {'page': page, 'start': range.apiStart, 'end': range.apiEnd, 'locale': _locale});
    return WalletPage.fromJson(root, page, (p, url, got) => nextPageOf(p, url, gotItems: got));
  }

  Future<CashoutPage> cashouts(PeriodRange range, int page) async {
    final root = await _api.postForm(EndPoints.cashoutTransactions, {'page': page, 'start': range.apiStart, 'end': range.apiEnd});
    return CashoutPage.fromJson(root, page, (p, url, got) => nextPageOf(p, url, gotItems: got));
  }

  /// Returns the server's message. A refusal (for example more than the balance) throws AppException with its message.
  Future<String> requestCashout(String amount) async {
    final root = await _api.postForm(EndPoints.requestCashout, {'amount': amount.trim(), 'locale': _locale});
    return root.text('message');
  }
}

final walletRepositoryProvider = Provider<WalletRepository>(
      (ref) => WalletRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);