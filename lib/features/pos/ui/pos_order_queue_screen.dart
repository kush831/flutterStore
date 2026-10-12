import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../data/pos_orders_models.dart';
import '../data/pos_orders_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_orders_logic.dart';
import '../logic/pos_orders_providers.dart';
import 'pos_order_card.dart';
import 'pos_widgets.dart';

/// The live pipeline: Waiting → Preparing → Ready, with the next step as a button. Jetpack's POSOrderQueueScreen.
class PosOrderQueueScreen extends ConsumerStatefulWidget {
  const PosOrderQueueScreen({super.key});

  @override
  ConsumerState<PosOrderQueueScreen> createState() => _PosOrderQueueScreenState();
}

class _PosOrderQueueScreenState extends ConsumerState<PosOrderQueueScreen> {
  int _status = kOrderNew;
  String? _movingId;

  String _tabKey(int s) => switch (s) {
    kOrderNew => 'pos_posorderqueuescreen_waiting',
    kOrderProcessing => 'pos_posorderqueuescreen_preparing',
    _ => 'pos_posorderqueuescreen_ready',
  };

  Future<void> _move(PosOrderRow o) async {
    final next = nextStatus(o.status);
    if (next == null) return;
    setState(() => _movingId = o.orderId);
    try {
      await ref.read(posOrdersRepositoryProvider).updateStatus(o.orderId, next);
      ref.invalidate(posOrdersProvider); // every list of orders is out of date now
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _movingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final auth = ref.watch(posAuthProvider);
    final key = PosOrdersKey(_status);
    final st = ref.watch(posOrdersProvider(key));
    final ctrl = ref.read(posOrdersProvider(key).notifier);
    final items = st.items;

    // the three tabs show their counts: each list loads its first page
    int? count(int s) => ref.watch(posOrdersTotalProvider(PosOrdersKey(s)));
    for (final s in kQueueStatuses) {
      if (s != _status) ref.watch(posOrdersProvider(PosOrdersKey(s)));
    }

    Widget tab(int s) {
      final n = count(s);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => setState(() => _status = s),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: s == _status ? toneColor(context, toneOf(s)).withValues(alpha: 0.14) : tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: s == _status ? toneColor(context, toneOf(s)) : tk.border)),
            child: Column(children: [
              Text(n == null ? '–' : '$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: s == _status ? toneColor(context, toneOf(s)) : tk.text1)),
              Text(context.str(_tabKey(s)), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tk.text2)),
            ]),
          ),
        ),
      );
    }

    final Widget list;
    if (st.showShimmer) {
      list = const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (st.showError) {
      list = FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posordersscreen_try_again', onAction: ctrl.refresh);
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      list = FinanceMessage(icon: Icons.inbox_outlined, title: context.str('pos_posorderqueuescreen_empty_default'));
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 500) ctrl.loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == items.length) return ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);
              final o = items[i];
              final perm = nextPermission(o.status);
              final key = nextActionKey(o.status);
              final allowed = perm != null && auth.can(perm); // the server has the last word; the buttons follow the staff member's permissions
              return PosOrderCard(
                order: o,
                action: (key == null || !allowed)
                    ? null
                    : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _movingId != null ? null : () => _move(o),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: toneColor(context, toneOf(nextStatus(o.status)!))),
                      child: _movingId == o.orderId ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : Text(context.str(key)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return PosPage(
      title: context.str('pos_posorderqueuescreen_title'),
      back: Routes.posOrders,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_posorderqueuescreen_subtitle'), style: TextStyle(color: tk.text2)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [for (var i = 0; i < kQueueStatuses.length; i++) ...[if (i > 0) const SizedBox(width: 8), tab(kQueueStatuses[i])]])),
        Expanded(child: list),
      ]),
    );
  }
}