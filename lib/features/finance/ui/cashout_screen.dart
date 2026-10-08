import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
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
import 'cashout_request_sheet.dart';
import 'finance_widgets.dart';

class CashoutScreen extends ConsumerStatefulWidget {
  const CashoutScreen({super.key});

  @override
  ConsumerState<CashoutScreen> createState() => _CashoutScreenState();
}

class _CashoutScreenState extends ConsumerState<CashoutScreen> {
  PeriodRange _range = PeriodRange.preset(PeriodPreset.all, DateTime.now());

  Future<void> _request(String balanceText) async {
    final message = await showCashoutRequest(context, balanceText: balanceText);
    if (message == null || !mounted) return;
    // the request is in the history, the balance has changed, and the wallet shows a new movement
    ref.invalidate(cashoutProvider);
    ref.invalidate(walletProvider);
    showAppSnack(context, message.isEmpty ? context.str('financialsmodule_financialsmodule_cashout_history_requestSubmittedSuccessfully') : message);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final st = ref.watch(cashoutProvider(_range));
    final ctrl = ref.read(cashoutProvider(_range).notifier);
    final balance = ref.watch(cashoutBalanceProvider(_range));
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final items = st.items;
    final balanceText = money(currency, balance ?? '');

    return SubPage(
      title: context.str('financialsmodule_financialsmodule_cashout_history_title'),
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
                icon: Icons.payments_outlined,
                title: context.str('financialsmodule_financialsmodule_no_cashout_transactions_message'),
                message: context.str('financialsmodule_financialsmodule_tryAdjustingDateRange').replaceAll(RegExp(r'\\+n'), '\n'),
              ),
            ),
          ];
        } else {
          list = [
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
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
                    child: BalanceHero(
                      labelKey: 'financialsmodule_financialsmodule_header_available_balance_title',
                      amount: balanceText,
                      loading: balance == null && st.showShimmer,
                      action: balance == null ? null : FilledButton(
                        onPressed: () => _request(balanceText),
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: context.primary, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        child: Text(context.str('financialsmodule_financialsmodule_cashout_history_requestCashout'), textAlign: TextAlign.center),
                      ),
                    ),
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

Color _toneColor(BuildContext context, CashoutTone t) {
  final tk = context.tk;
  return switch (t) {
    CashoutTone.pending => tk.warning,
    CashoutTone.approved => tk.success,
    CashoutTone.rejected => tk.danger,
    CashoutTone.neutral => tk.text2,
  };
}

class _Card extends StatelessWidget {
  const _Card({required this.e, required this.currency});

  final CashoutEntry e;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget line(String key, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(TextSpan(children: [TextSpan(text: '${context.str(key)}: ', style: TextStyle(color: tk.text3)), TextSpan(text: value, style: TextStyle(color: tk.text2))]), style: const TextStyle(fontSize: 12.5)),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text(money(currency, e.amount), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1))), StatusChip(e.status, _toneColor(context, e.tone))]),
            const SizedBox(height: 4),
            line('financialsmodule_financialsmodule_transaction_id_title', e.transactionId),
            line('financialsmodule_financialsmodule_cashout_history_actionBy', e.actionBy),
            line('financialsmodule_financialsmodule_cashout_history_comment', e.comment),
          ],
        ),
      ),
    );
  }
}

const _cols = <int>[22, 14, 14, 16, 34]; // transaction id, amount, status, action by, comment

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
        cell(0, 'financialsmodule_financialsmodule_transaction_id_title'),
        cell(1, 'financialsmodule_financialsmodule_cashout_history_amount', end: true),
        const SizedBox(width: 16),
        cell(2, 'settings_settings_row_status'),
        cell(3, 'financialsmodule_financialsmodule_cashout_history_actionBy'),
        cell(4, 'financialsmodule_financialsmodule_cashout_history_comment'),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.e, required this.currency});

  final CashoutEntry e;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
        child: Row(children: [
          Expanded(flex: _cols[0], child: SelectableText(e.transactionId, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
          Expanded(flex: _cols[1], child: Text(money(currency, e.amount), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
          const SizedBox(width: 16),
          Expanded(flex: _cols[2], child: Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(e.status, _toneColor(context, e.tone)))),
          Expanded(flex: _cols[3], child: Text(e.actionBy.isEmpty ? '—' : e.actionBy, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
          Expanded(flex: _cols[4], child: Text(e.comment.isEmpty ? '—' : e.comment, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
        ]),
      ),
    );
  }
}