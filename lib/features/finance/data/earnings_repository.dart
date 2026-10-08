import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/period_range.dart';
import 'earnings_models.dart';

class EarningsRepository {
  EarningsRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// "All" sends no dates (the ApiClient drops null fields).
  Future<EarningsPage> page(PeriodRange range, int page) async {
    final root = await _api.postForm(EndPoints.earnings, {
      'page': page,
      'start': range.apiStart,
      'end': range.apiEnd,
      'locale': _prefs.language ?? 'en',
    });
    return EarningsPage.fromJson(root, page, (p, url, got) => nextPageOf(p, url, gotItems: got));
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>(
      (ref) => EarningsRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);