import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
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
/// Phone and a narrow tablet: the tabs and one list. A wide tablet and a browser (900 px of content): a board with a column for each stage.
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

  /// The orders of one stage: the same list in the tabs and in a board column.
  Widget _orderList(int status, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)}) => Consumer(builder: (context, ref, _) {
    final tk = context.tk;
    final auth = ref.watch(posAuthProvider);
    final key = PosOrdersKey(status);
    final st = ref.watch(posOrdersProvider(key));
    final ctrl = ref.read(posOrdersProvider(key).notifier);
    final items = st.items;

    if (st.showShimmer) return const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: ListSkeleton());
    if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posordersscreen_try_again', onAction: ctrl.refresh);
    if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.inbox_outlined, title: context.str('pos_posorderqueuescreen_empty_default'));

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == items.length) return ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);
            final o = items[i];
            final perm = nextPermission(o.status);
            final actionKey = nextActionKey(o.status);
            final allowed = perm != null && auth.can(perm); // the server has the last word; the buttons follow the staff member's permissions
            return PosOrderCard(
              order: o,
              action: (actionKey == null || !allowed)
                  ? null
                  : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _movingId != null ? null : () => _move(o),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: toneColor(context, toneOf(nextStatus(o.status)!))),
                    child: _movingId == o.orderId ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : Text(context.str(actionKey)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final title = context.str('pos_posorderqueuescreen_title');

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

    // the tabs and one list
    Widget tabsView({double hPad = 16}) => Column(children: [
      Padding(padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_posorderqueuescreen_subtitle'), style: TextStyle(color: tk.text2)))),
      Padding(padding: EdgeInsets.symmetric(horizontal: hPad), child: Row(children: [for (var i = 0; i < kQueueStatuses.length; i++) ...[if (i > 0) const SizedBox(width: 8), tab(kQueueStatuses[i])]])),
      Expanded(child: _orderList(_status, padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24))),
    ]);

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) return PosPage(title: title, back: Routes.posOrders, child: tabsView());

    // ══ tablet and browser ════════════════════════════════════════════════════
    return AdaptivePage(
      title: title,
      subtitle: context.str('pos_posorderqueuescreen_subtitle'),
      fallbackRoute: Routes.posOrders,
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 900) return tabsView(hPad: 0);

        // the board: a column for each stage, each with its own scroll
        Widget column(int s) {
          final n = count(s);
          final c = toneColor(context, toneOf(s));
          return Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [
                  Text(n == null ? '–' : '$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                  const SizedBox(width: 10),
                  Text(context.str(_tabKey(s)), style: TextStyle(fontWeight: FontWeight.w700, color: c)),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(child: _orderList(s, padding: const EdgeInsets.only(bottom: 24))),
            ]),
          );
        }

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < kQueueStatuses.length; i++) ...[if (i > 0) const SizedBox(width: 16), column(kQueueStatuses[i])]]);
      }),
    );
  }
}