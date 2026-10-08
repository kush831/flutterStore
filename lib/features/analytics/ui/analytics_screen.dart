import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../../splash/ui/brand_widgets.dart';
import '../logic/analytics_logic.dart';
import '../logic/analytics_providers.dart';
import 'analytics_charts.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.monthly;

  Future<void> _refresh() async {
    ref.invalidate(analyticsProvider(_period));
    try {
      await ref.read(analyticsProvider(_period).future);
    } catch (_) {} // the error shows on screen
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final async = ref.watch(analyticsProvider(_period));
    final data = async.value;
    final dashCurrency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));

    final Widget body;
    if (data != null) {
      body = _Dashboard(data: data, currency: data.currency.isNotEmpty ? data.currency : dashCurrency);
    } else if (async.hasError) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(context.str('common_allscreen_something_went_wrong'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: _refresh, child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      body = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 110, radius: 16), SizedBox(height: 12), SkeletonBox(height: 80, radius: 16), SizedBox(height: 12), SkeletonBox(height: 220, radius: 16), SizedBox(height: 12), SkeletonBox(height: 150, radius: 16)]));
    }

    String label(AnalyticsPeriod p) => context.str(switch (p) {
      AnalyticsPeriod.daily => 'storedetails_storeanalytics_range_daily_title',
      AnalyticsPeriod.weekly => 'storedetails_storeanalytics_range_weekly_title',
      AnalyticsPeriod.monthly => 'storedetails_storeanalytics_range_monthly_title',
    });

    final switcher = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [
        for (final p in AnalyticsPeriod.values)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: p == _period ? tk.surface : Colors.transparent, borderRadius: BorderRadius.circular(Radii.sm), border: Border.all(color: p == _period ? tk.border : Colors.transparent)),
                child: Center(child: Text(label(p), style: TextStyle(fontSize: 13.5, fontWeight: p == _period ? FontWeight.w700 : FontWeight.w500, color: p == _period ? tk.text1 : tk.text2))),
              ),
            ),
          ),
      ]),
    );

    return SubPage(
      title: context.str('storedetails_storeanalytics_title'),
      fallbackRoute: Routes.more,
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: switcher)),
            const SizedBox(height: 14),
            body,
          ],
        ),
      ),
    );
  }
}

// ── the dashboard ────────────────────────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.currency});

  final AnalyticsData data;
  final String currency;

  /// A short label for a bar: the day of the month, the start of the week, or the month.
  String _label(BuildContext context, BucketRange r) {
    final loc = MaterialLocalizations.of(context);
    switch (data.period) {
      case AnalyticsPeriod.daily:
        return '${r.start.day}';
      case AnalyticsPeriod.weekly:
        return loc.formatShortMonthDay(r.start);
      case AnalyticsPeriod.monthly:
        return loc.formatMonthYear(r.start).characters.take(3).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    String money0(double v) => money(currency, amountText(v));

    final hero = _Hero(label: context.str('storedetails_storeanalytics_total_revenue_title'), value: money0(data.current.revenue), change: data.revenueChange);
    final orders = _Kpi(label: context.str('storedetails_storeanalytics_total_orders_title'), value: '${data.current.orders}', change: data.ordersChange);
    final avg = _Kpi(label: context.str('storedetails_storeanalytics_avg_order_value_title'), value: money0(data.current.avgOrder), change: data.avgOrderChange);
    final rate = _Kpi(label: context.str('storedetails_storeanalytics_store_earnings_title'), value: '${data.current.storeRate.toStringAsFixed(1)}%', change: data.storeRateChange);

    final chart = _Card(
      titleKey: 'storedetails_storeanalytics_sales_overview_title',
      child: BarChartView(
        values: [for (final b in data.buckets) b.revenue],
        labels: [for (final r in data.ranges) _label(context, r)],
        format: money0,
        initialSelected: data.bestIndex,
        height: wide ? 250 : 200,
      ),
    );

    final total = data.current.store + data.current.merchant;
    final storePct = total > 0 ? data.current.store / total * 100 : 0.0;
    Widget legend(Color c, String labelKey, double amount, double pct) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(context.str(labelKey), style: TextStyle(color: tk.text2))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), Text(money0(amount), style: TextStyle(fontSize: 11.5, color: tk.text3))]),
      ]),
    );
    final split = _Card(
      titleKey: 'storedetails_storeanalytics_earnings_split_title',
      child: Column(children: [
        DonutView(
          first: data.current.store,
          second: data.current.merchant,
          firstColor: context.primary,
          secondColor: tk.info,
          size: wide ? 130 : 120,
          child: Text('${storePct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
        ),
        const SizedBox(height: 14),
        legend(context.primary, 'storedetails_storeanalytics_store', data.current.store, storePct),
        legend(tk.info, 'storedetails_storeanalytics_merchant', data.current.merchant, total > 0 ? 100 - storePct : 0),
      ]),
    );

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 14, child: hero), const SizedBox(width: 12), Expanded(flex: 10, child: orders), const SizedBox(width: 12), Expanded(flex: 10, child: avg), const SizedBox(width: 12), Expanded(flex: 10, child: rate)]),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 18, child: chart), const SizedBox(width: 12), Expanded(flex: 10, child: split)]),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: orders), const SizedBox(width: 10), Expanded(child: avg)]),
        ),
        const SizedBox(height: 10),
        rate,
        const SizedBox(height: 12),
        chart,
        const SizedBox(height: 12),
        split,
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.label, required this.value, required this.change});

  final String label;
  final String value;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: on.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: on))),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(change! >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 15, color: on),
              const SizedBox(width: 3),
              Text('${change!.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.change});

  final String label;
  final String value;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final up = (change ?? 0) >= 0;
    final c = up ? tk.success : tk.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: tk.text1))),
          const SizedBox(height: 4),
          if (change == null)
            Text('—', style: TextStyle(color: tk.text3))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: c),
              const SizedBox(width: 2),
              Text('${change!.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
            ]),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.titleKey, required this.child});

  final String titleKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tk.text1))),
          child,
        ],
      ),
    ),
  );
}