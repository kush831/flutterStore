import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/period_filter.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../../core/time/period_range.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/wallet_models.dart';
import '../logic/wallet_providers.dart';
import 'finance_widgets.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  PeriodRange _range = PeriodRange.preset(PeriodPreset.all, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final st = ref.watch(walletProvider(_range));
    final ctrl = ref.read(walletProvider(_range).notifier);
    final balance = ref.watch(walletBalanceProvider(_range));
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final items = st.items;

    return SubPage(
      title: context.str('settings_settings_row_walletTransactions'),
      fallbackRoute: Routes.more,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 760;

        final List<Widget> list;
        if (st.showShimmer) {
          list = [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const ListSkeleton()))];
        } else if (st.showError) {
          list = [SliverFillRemaining(hasScrollBody: false, child: FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'common_allscreen_try_again', onAction: ctrl.refresh))];
        } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
          list = [
            SliverFillRemaining(
              hasScrollBody: false,
              child: FinanceMessage(
                icon: Icons.account_balance_wallet_outlined,
                title: context.str('financialsmodule_financialsmodule_no_transactions_found_message'),
                message: context.str('financialsmodule_financialsmodule_tryAdjustingDateRange').replaceAll(RegExp(r'\\+n'), '\n'),
              ),
            ),
          ];
        } else {
          list = [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 10),
                child: Text(context.str('financialsmodule_financialsmodule_all_transactions_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
              ),
            ),
            if (wide) ...[
              const SliverToBoxAdapter(child: _TableHeader()),
              SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => _Row(e: items[i], currency: currency)),
            ] else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.separated(itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) => _Card(e: items[i], currency: currency)),
              ),
            SliverToBoxAdapter(child: ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ];
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 500) ctrl.loadMore();
            return false;
          },
          child: RefreshIndicator(
            color: context.primary,
            onRefresh: ctrl.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: PeriodFilter(value: _range, onChanged: (r) => setState(() => _range = r), horizontalPadding: pad)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: BalanceHero(labelKey: 'financialsmodule_financialsmodule_header_available_balance_title', amount: money(currency, balance ?? ''), loading: balance == null && st.showShimmer),
                  ),
                ),
                ...list,
              ],
            ),
          ),
        );
      }),
    );
  }
}

String _signed(WalletEntry e, String currency) => '${e.debit ? '−' : '+'}${money(currency, e.magnitude)}';

class _Card extends StatelessWidget {
  const _Card({required this.e, required this.currency});

  final WalletEntry e;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = e.debit ? tk.danger : tk.success;
    final sub = [e.paymentMode, e.on].where((s) => s.isNotEmpty).join('  ·  ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(e.debit ? Icons.north_east_rounded : Icons.south_west_rounded, size: 19, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.narration, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1, height: 1.3)),
                  if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text3))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(_signed(e, currency), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      ),
    );
  }
}

const _cols = <int>[18, 34, 14, 12, 16]; // date, description, payment, type, amount

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.text2);
    Widget cell(int i, String key, {bool end = false}) => Expanded(flex: _cols[i], child: Text(context.str(key), textAlign: end ? TextAlign.end : TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: style));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: tk.sunken, border: Border(top: BorderSide(color: tk.border), bottom: BorderSide(color: tk.border)), borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md))),
      child: Row(children: [
        cell(0, 'pos_posreceiptscreen_label_date_short'),
        cell(1, 'products_products_description_title'),
        cell(2, 'orders_ordersscreen_payment_title'),
        cell(3, 'pos_posreceiptscreen_label_type'),
        cell(4, 'financialsmodule_financialsmodule_cashout_history_amount', end: true),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.e, required this.currency});

  final WalletEntry e;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = e.debit ? tk.danger : tk.success;
    return Material(
      color: tk.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
        child: Row(children: [
          Expanded(flex: _cols[0], child: Text(e.on, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2))),
          Expanded(flex: _cols[1], child: Text(e.narration, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
          Expanded(flex: _cols[2], child: Text(e.paymentMode, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
          Expanded(flex: _cols[3], child: Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(e.type, c))),
          Expanded(flex: _cols[4], child: Text(_signed(e, currency), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: c))),
        ]),
      ),
    );
  }
}