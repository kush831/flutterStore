import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/period_filter.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../../core/time/period_range.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../../splash/ui/brand_widgets.dart';
import '../data/earnings_models.dart';
import '../logic/earnings_providers.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  PeriodRange _range = PeriodRange.preset(PeriodPreset.month, DateTime.now()); // Jetpack's default is not visible; this month is a sensible start

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final st = ref.watch(earningsProvider(_range));
    final ctrl = ref.read(earningsProvider(_range).notifier);
    final summary = ref.watch(earningsSummaryProvider(_range));
    final dashCurrency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final currency = (summary?.currency.isNotEmpty ?? false) ? summary!.currency : dashCurrency;
    final items = st.items;

    return SubPage(
      title: context.str('storedetails_storeanalytics_store_earnings_title'),
      fallbackRoute: Routes.more,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 760;

        final List<Widget> list;
        if (st.showShimmer) {
          list = [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _ListSkeleton()))];
        } else if (st.showError) {
          list = [SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'common_allscreen_try_again', onAction: ctrl.refresh))];
        } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
          list = [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                icon: Icons.payments_outlined,
                title: context.str('financialsmodule_financialsmodule_noEarningsYet'),
                message: context.str('financialsmodule_financialsmodule_tryAdjustingDateRange').replaceAll(RegExp(r'\\+n'), '\n'),
              ),
            ),
          ];
        } else {
          list = [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 10),
                child: Text(context.str('financialsmodule_financialsmodule_orderBreakDown'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
              ),
            ),
            if (wide) ...[
              const SliverToBoxAdapter(child: _TableHeader()),
              SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => _OrderRow(o: items[i], currency: currency)),
            ] else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.separated(itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) => _OrderCard(o: items[i], currency: currency)),
              ),
            SliverToBoxAdapter(child: _Footer(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
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
                SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: _Summary(summary: summary, currency: currency, wide: wide, loading: summary == null && st.showShimmer))),
                ...list,
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── summary ──────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.currency, required this.wide, required this.loading});

  final EarningsSummary? summary;
  final String currency;
  final bool wide;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SkeletonPulse(child: wide ? const Row(children: [Expanded(flex: 14, child: SkeletonBox(height: 104, radius: 16)), SizedBox(width: 10), Expanded(flex: 10, child: SkeletonBox(height: 104, radius: 16)), SizedBox(width: 10), Expanded(flex: 10, child: SkeletonBox(height: 104, radius: 16)), SizedBox(width: 10), Expanded(flex: 10, child: SkeletonBox(height: 104, radius: 16))]) : const Column(children: [SkeletonBox(height: 120, radius: 16), SizedBox(height: 10), Row(children: [Expanded(child: SkeletonBox(height: 78, radius: 16)), SizedBox(width: 10), Expanded(child: SkeletonBox(height: 78, radius: 16)), SizedBox(width: 10), Expanded(child: SkeletonBox(height: 78, radius: 16))])]));
    }
    final s = summary ?? const EarningsSummary();
    final brand = context.primary;
    final on = onColor(brand);

    final hero = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.str('financialsmodule_financialsmodule_totalStoreEarnings'), style: TextStyle(fontSize: 13, color: on.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(money(currency, s.storeEarning), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: on))),
          const SizedBox(height: 2),
          Text(context.str('financialsmodule_financialsmodule_basedOnSelectedPeriod'), style: TextStyle(fontSize: 12, color: on.withValues(alpha: 0.8))),
        ],
      ),
    );

    Widget stat(String key, String value) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: context.tk.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.str(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.tk.text2)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.tk.text1))),
        ],
      ),
    );

    final orders = stat('financialsmodule_financialsmodule_total_orders_title', '${s.totalOrders}');
    final amount = stat('financialsmodule_financialsmodule_order_amount_title', money(currency, s.orderAmount));
    final merchant = stat('financialsmodule_financialsmodule_merchant_earning_title', money(currency, s.merchantEarning));

    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 14, child: hero), const SizedBox(width: 10), Expanded(flex: 10, child: orders), const SizedBox(width: 10), Expanded(flex: 10, child: amount), const SizedBox(width: 10), Expanded(flex: 10, child: merchant)]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hero, const SizedBox(height: 10), Row(children: [Expanded(child: orders), const SizedBox(width: 10), Expanded(child: amount), const SizedBox(width: 10), Expanded(child: merchant)])]);
  }
}

// ── phone: a card per order ──────────────────────────────────────────────────

String _when(BuildContext context, EarningOrder o) {
  final d = o.createdDate;
  if (d == null) return o.createdAt;
  final loc = MaterialLocalizations.of(context);
  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
  return '${loc.formatShortDate(d)}  ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(d), alwaysUse24HourFormat: h24)}';
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.o, required this.currency});

  final EarningOrder o;
  final String currency;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final o = widget.o;
    final cur = widget.currency;

    Widget line(String key, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(context.str(key), style: TextStyle(fontSize: 13, color: bold ? tk.text1 : tk.text2, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Text(money(cur, value), style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1)),
      ]),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${context.str('financialsmodule_financialsmodule_order_id')} ${o.orderId}', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                    Text(_when(context, o), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(cur, o.storeEarning), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.success)),
                  Text(money(cur, o.orderAmount), style: TextStyle(fontSize: 12, color: tk.text3)),
                ]),
                const SizedBox(width: 4),
                Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: tk.text3),
              ]),
              if (_open) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: tk.border),
                const SizedBox(height: 6),
                line('financialsmodule_financialsmodule_cartAmount', o.cartAmount),
                line('financialsmodule_financialsmodule_deliveryCharges', o.deliveryCharges),
                if (o.otherCharges.isNotEmpty) line('financialsmodule_financialsmodule_otherCharges', o.otherCharges),
                line('financialsmodule_financialsmodule_tax_deducted_title', o.tax),
                Divider(height: 14, color: tk.border),
                line('financialsmodule_financialsmodule_order_amount_title', o.orderAmount, bold: true),
                line('financialsmodule_financialsmodule_merchant_earning_title', o.merchantEarning),
                line('financialsmodule_financialsmodule_store_earning_title', o.storeEarning, bold: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── wide: the breakdown table ────────────────────────────────────────────────

const _cols = <int>[9, 15, 9, 9, 9, 9, 11, 12, 12]; // order, date, cart, delivery, other, tax, order amount, merchant, store

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.text2);
    Widget cell(int i, String key, {bool end = true}) => Expanded(flex: _cols[i], child: Text(context.str(key), textAlign: end ? TextAlign.end : TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: style));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: tk.sunken, border: Border(top: BorderSide(color: tk.border), bottom: BorderSide(color: tk.border)), borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md))),
      child: Row(children: [
        cell(0, 'financialsmodule_financialsmodule_order_id', end: false),
        Expanded(flex: _cols[1], child: Icon(Icons.schedule_rounded, size: 16, color: tk.text2)),
        cell(2, 'financialsmodule_financialsmodule_cartAmount'),
        cell(3, 'financialsmodule_financialsmodule_deliveryCharges'),
        cell(4, 'financialsmodule_financialsmodule_otherCharges'),
        cell(5, 'financialsmodule_financialsmodule_tax_deducted_title'),
        cell(6, 'financialsmodule_financialsmodule_order_amount_title'),
        cell(7, 'financialsmodule_financialsmodule_merchant_earning_title'),
        cell(8, 'financialsmodule_financialsmodule_store_earning_title'),
      ]),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.o, required this.currency});

  final EarningOrder o;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget num(int i, String v, {bool bold = false, Color? color}) => Expanded(
      flex: _cols[i],
      child: Text(v.isEmpty ? '—' : money(currency, v), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? (bold ? tk.text1 : tk.text2))),
    );
    return Material(
      color: tk.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
        child: Row(children: [
          Expanded(flex: _cols[0], child: Text(o.orderId, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
          Expanded(flex: _cols[1], child: Text(_when(context, o), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2))),
          num(2, o.cartAmount),
          num(3, o.deliveryCharges),
          num(4, o.otherCharges),
          num(5, o.tax),
          num(6, o.orderAmount, bold: true),
          num(7, o.merchantEarning),
          num(8, o.storeEarning, bold: true, color: tk.success),
        ]),
      ),
    );
  }
}

// ── states ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.hasMore, required this.loading, required this.failed, required this.onRetry});

  final bool hasMore;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) return Padding(padding: const EdgeInsets.all(12), child: Center(child: TextButton(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))));
    if (loading || hasMore) return const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    return const SizedBox.shrink();
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(child: Column(children: [const SizedBox(height: 16), for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 70, radius: 16))]));
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.message, this.actionKey, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionKey;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45))],
          if (onAction != null && actionKey != null) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: onAction, child: Text(context.str(actionKey!)))],
        ]),
      ),
    );
  }
}