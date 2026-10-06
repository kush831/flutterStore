import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';

class DemoAccounts {
  const DemoAccounts(this.food, this.grocery);

  final List<String> food;
  final List<String> grocery;
}

class DemoRepository {
  DemoRepository(this._api);

  final ApiClient _api;

  /// Throws AppException. Entries without an email are skipped (Jetpack crashed on them).
  Future<DemoAccounts> accounts() async {
    final root = await _api.postForm(EndPoints.loginAsDemo);
    final d = root.sub('data');
    List<String> emails(String key) => [
      for (final e in d.list(key, (r) => r.text('email').trim())) if (e.isNotEmpty) e,
    ];
    return DemoAccounts(emails('Foods'), emails('Grocery'));
  }
}

final demoRepositoryProvider = Provider<DemoRepository>((ref) => DemoRepository(ref.watch(apiClientProvider)));

final demoAccountsProvider = FutureProvider.autoDispose<DemoAccounts>((ref) => ref.watch(demoRepositoryProvider).accounts());