import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../data/pos_orders_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_orders_logic.dart';
import '../logic/pos_orders_providers.dart';
import '../logic/pos_shift_logic.dart';
import '../../home/ui/home_format.dart';
import 'pos_order_card.dart';
import 'pos_widgets.dart';

/// The POS Orders tab: search, status tabs, and the orders of the shift. Jetpack's POSOrdersScreen.
/// Phone: cards in one column. Tablet: cards in two columns. Wide tablet and browser: the store app's page header and a table.
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

  void _clear() {
    _field.clear();
    _debounce?.cancel();
    setState(() => _search = '');
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final key = PosOrdersKey(_tab.status, _search);
    final st = ref.watch(posOrdersProvider(key));
    final ctrl = ref.read(posOrdersProvider(key).notifier);
    final total = ref.watch(posOrdersTotalProvider(key));
    final currency = ref.watch(posCurrencyProvider);
    final items = st.items;

    final searchField = TextField(
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
        suffixIcon: _field.text.isEmpty ? null : TextButton(onPressed: _clear, child: Text(context.str('pos_posordersscreen_clear'))),
      ),
    );

    Widget tabChips({double hPad = 16}) => ListView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
      children: [
        for (final t in PosOrdersTab.values)
          Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(context.str(t.tabKey)), selected: t == _tab, onSelected: (_) => setState(() => _tab = t))),
      ],
    );

    Widget countLine() {
      final n = total ?? items.length;
      return Text(context.str(n == 1 ? 'pos_posordersscreen_section_orders_count' : 'pos_posordersscreen_section_orders_count_plural', [n]), style: TextStyle(color: tk.text2));
    }

    // the states that are the same on every width
    Widget? state() {
      if (st.showShimmer) return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posordersscreen_try_again', onAction: ctrl.refresh);
      if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.receipt_long_outlined, title: context.str(_tab.emptyKey), message: context.str(_tab.emptySubKey));
      return null;
    }

    Widget scrolling(Widget child) => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(color: context.primary, onRefresh: ctrl.refresh, child: child),
    );

    final footer = ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);

    // ── cards: one column on a phone, two on a tablet ────────────────────────
    Widget cards(int cols, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 4, 16, 24)}) {
      final rows = (items.length / cols).ceil();
      return scrolling(
        ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: rows + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) return Padding(padding: const EdgeInsets.only(left: 4), child: countLine());
            if (i <= rows) {
              final start = (i - 1) * cols;
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: start + c < items.length ? PosOrderCard(order: items[start + c]) : const SizedBox.shrink()),
                ],
              ]);
            }
            return footer;
          },
        ),
      );
    }

    // ── the table: browser and wide tablet ───────────────────────────────────
    Widget table() {
      Widget head(String key, {int flex = 1, TextAlign align = TextAlign.start}) => Expanded(flex: flex, child: Text(context.str(key), textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3)));
      Widget cell(String text, {int flex = 1, TextAlign align = TextAlign.start, bool bold = false, Color? color}) => Expanded(flex: flex, child: Text(text, textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? tk.text1)));

      Widget row(PosOrderRow o) {
        final name = o.customerName.trim().isEmpty ? context.str('pos_posordersscreen_walk_in') : o.customerName;
        final method = o.paymentMethod.isEmpty ? '—' : o.paymentMethod[0].toUpperCase() + o.paymentMethod.substring(1);
        return InkWell(
          onTap: () => context.push('${Routes.posOrder}/${Uri.encodeComponent(o.orderId)}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border))),
            child: Row(children: [
              cell('# ${o.orderNumber}', flex: 12, bold: true),
              cell(name, flex: 22),
              Expanded(flex: 14, child: Align(alignment: AlignmentDirectional.centerStart, child: PosChip(context.str(orderTypeKey(o.orderType)), context.primary))),
              cell('${o.quantity}', flex: 7),
              cell(o.date.isEmpty ? '—' : posDateTime(context, o.date), flex: 20, color: tk.text2),
              cell(method, flex: 11, color: tk.text2),
              cell(money(currency, posAmountText(o.amount)), flex: 13, align: TextAlign.end, bold: true),
              Expanded(flex: 16, child: Align(alignment: AlignmentDirectional.centerEnd, child: PosStatusBadge(status: o.status, serverText: o.statusText))),
            ]),
          ),
        );
      }

      return scrolling(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: countLine()),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Container(
                  color: tk.sunken,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    head('pos_posordersscreen_col_order', flex: 12),
                    head('pos_posordersscreen_col_customer', flex: 22),
                    head('pos_posordersscreen_col_type', flex: 14),
                    head('pos_posordersscreen_col_items', flex: 7),
                    head('pos_posordersscreen_col_time', flex: 20),
                    head('pos_posordersscreen_col_payment', flex: 11),
                    head('pos_posordersscreen_col_amount', flex: 13, align: TextAlign.end),
                    head('pos_posordersscreen_col_status', flex: 16, align: TextAlign.end),
                  ]),
                ),
                for (final o in items) row(o),
              ]),
            ),
            footer,
          ],
        ),
      );
    }

    // ══ phone: exactly what it was (cards, one column) ════════════════════════
    if (!wide) {
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
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: searchField),
            SizedBox(height: 50, child: tabChips()),
            Expanded(child: state() ?? cards(1)),
          ],
        ),
      );
    }

    // ══ tablet and browser: the store app's page header ═══════════════════════
    return AdaptivePage(
      title: context.str('pos_posordersscreen_title'),
      subtitle: context.str('pos_posordersscreen_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.posOrderQueue),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.view_kanban_outlined, size: 20),
          label: Text(context.str('pos_posorderqueuescreen_title')),
        ),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final asTable = box.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the search and the tabs on one row when there is room, else the tabs under the search
            if (box.maxWidth >= 760)
              SizedBox(height: 50, child: Row(children: [SizedBox(width: 300, child: searchField), const SizedBox(width: 16), Expanded(child: tabChips(hPad: 0))]))
            else ...[
              searchField,
              SizedBox(height: 50, child: tabChips(hPad: 0)),
            ],
            const SizedBox(height: 8),
            Expanded(child: state() ?? (asTable ? table() : cards(2, padding: const EdgeInsets.fromLTRB(0, 4, 0, 24)))),
          ],
        );
      }),
    );
  }
}