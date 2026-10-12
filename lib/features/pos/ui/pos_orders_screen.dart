import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../logic/pos_orders_logic.dart';
import '../logic/pos_orders_providers.dart';
import 'pos_order_card.dart';

/// The POS Orders tab: search, status tabs, and the orders of the shift. Jetpack's POSOrdersScreen.
class PosOrdersScreen extends ConsumerStatefulWidget {
  const PosOrdersScreen({super.key, this.initialTab});

  final String? initialTab; // ?tab=cancelled

  @override
  ConsumerState<PosOrdersScreen> createState() => _PosOrdersScreenState();
}

class _PosOrdersScreenState extends ConsumerState<PosOrdersScreen> {
  late PosOrdersTab _tab = PosOrdersTab.fromName(widget.initialTab);
  final _field = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void didUpdateWidget(PosOrdersScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) setState(() => _tab = PosOrdersTab.fromName(widget.initialTab)); // "Cancel Order" opens the Cancelled tab
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final key = PosOrdersKey(_tab.status, _search);
    final st = ref.watch(posOrdersProvider(key));
    final ctrl = ref.read(posOrdersProvider(key).notifier);
    final total = ref.watch(posOrdersTotalProvider(key));
    final items = st.items;

    final Widget list;
    if (st.showShimmer) {
      list = const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (st.showError) {
      list = FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posordersscreen_try_again', onAction: ctrl.refresh);
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      list = FinanceMessage(icon: Icons.receipt_long_outlined, title: context.str(_tab.emptyKey), message: context.str(_tab.emptySubKey));
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 500) ctrl.loadMore();
          return false;
        },
        child: RefreshIndicator(
          color: context.primary,
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length + 2,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                final n = total ?? items.length;
                return Padding(padding: const EdgeInsets.only(left: 4), child: Text(context.str(n == 1 ? 'pos_posordersscreen_section_orders_count' : 'pos_posordersscreen_section_orders_count_plural', [n]), style: TextStyle(color: tk.text2)));
              }
              if (i <= items.length) return PosOrderCard(order: items[i - 1]);
              return ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.str('pos_posordersscreen_title'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1)),
                  Text(context.str('pos_posordersscreen_subtitle'), style: TextStyle(color: tk.text2)),
                ]),
              ),
              IconButton(onPressed: () => context.push(Routes.posOrderQueue), tooltip: context.str('pos_posorderqueuescreen_title'), icon: const Icon(Icons.view_kanban_outlined)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _field,
              onChanged: _typed,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _debounce?.cancel();
                setState(() => _search = v.trim());
              },
              decoration: InputDecoration(
                hintText: context.str('pos_posordersscreen_search_placeholder'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _field.text.isEmpty
                    ? null
                    : TextButton(
                  onPressed: () {
                    _field.clear();
                    _debounce?.cancel();
                    setState(() => _search = '');
                  },
                  child: Text(context.str('pos_posordersscreen_clear')),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final t in PosOrdersTab.values)
                  Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(context.str(t.tabKey)), selected: t == _tab, onSelected: (_) => setState(() => _tab = t))),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}