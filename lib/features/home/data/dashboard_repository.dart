import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> home() async => DashboardData.fromJson(await _api.postForm(EndPoints.homeScreen));

  Future<BusinessSummary> summary() async => BusinessSummary.fromJson(await _api.postForm(EndPoints.orderStatistics));

  /// Throws AppException (the server's message when it refuses).
  Future<void> setStoreOpen(bool open) async {
    await _api.postForm(EndPoints.updateStoreStatus, {'is_open': open ? '1' : '0'});
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(apiClientProvider)));