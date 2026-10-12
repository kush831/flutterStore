import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_report_logic.dart';
import 'pos_report_models.dart';

class PosReportRepository {
  PosReportRepository(this._api);

  final ApiClient _api;

  /// The report of the shift. With a [period] (today, week, month) it is the Analytics view.
  Future<PosReport> report(String sessionId, {String? period}) async => PosReport.fromJson(await _api.postForm(EndPoints.posReport, reportBody(sessionId, period: period)));
}

final posReportRepositoryProvider = Provider<PosReportRepository>((ref) => PosReportRepository(ref.watch(posApiProvider)));