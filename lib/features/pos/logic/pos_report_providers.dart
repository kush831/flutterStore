import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pos_report_models.dart';
import '../data/pos_report_repository.dart';
import '../data/pos_repository.dart';
import 'pos_auth.dart';

Future<String> _session(Ref ref) async {
  try {
    return (await ref.watch(posActiveSessionProvider.future))?.id ?? '';
  } catch (_) {
    return '';
  }
}

/// The Dashboard's report: the open shift.
final posDashboardReportProvider = FutureProvider.autoDispose<PosReport>((ref) async {
  ref.watch(posScopeProvider);
  return ref.watch(posReportRepositoryProvider).report(await _session(ref));
});

/// Analytics: the same report for a period.
final posAnalyticsReportProvider = FutureProvider.autoDispose.family<PosReport, String>((ref, period) async {
  ref.watch(posScopeProvider);
  return ref.watch(posReportRepositoryProvider).report(await _session(ref), period: period);
});