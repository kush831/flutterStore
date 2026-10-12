import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paging.dart';
import '../data/pos_orders_models.dart';
import '../data/pos_orders_repository.dart';
import '../data/pos_repository.dart';
import 'pos_auth.dart';

/// Which list of orders: a status (null = all) and a search text.
@immutable
class PosOrdersKey {
  const PosOrdersKey(this.status, [this.search = '']);

  final int? status;
  final String search;

  @override
  bool operator ==(Object other) => other is PosOrdersKey && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

/// The "N orders" of a list, which comes with its first page.
class PosOrdersTotal extends Notifier<int?> {
  PosOrdersTotal(this.key);

  final PosOrdersKey key;

  @override
  int? build() => null;

  void set(int total) => state = total;
}

final posOrdersTotalProvider = NotifierProvider.autoDispose.family<PosOrdersTotal, int?, PosOrdersKey>(PosOrdersTotal.new);

class PosOrdersController extends PagedNotifier<PosOrderRow> {
  PosOrdersController(this.key);

  final PosOrdersKey key;

  @override
  PagedState<PosOrderRow> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosOrderRow>> fetchPage(int page) async {
    // the orders of the open shift (Jetpack sends the shift's id); with no open shift the server decides
    String session = '';
    try {
      session = (await ref.read(posActiveSessionProvider.future))?.id ?? '';
    } catch (_) {}
    final r = await ref.read(posOrdersRepositoryProvider).orders(sessionId: session, search: key.search, status: key.status?.toString() ?? '', page: page);
    if (page == 1 && ref.mounted) ref.read(posOrdersTotalProvider(key).notifier).set(r.total);
    return PageResult(r.items, r.next);
  }
}

final posOrdersProvider = NotifierProvider.autoDispose.family<PosOrdersController, PagedState<PosOrderRow>, PosOrdersKey>(PosOrdersController.new);