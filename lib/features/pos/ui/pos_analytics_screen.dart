import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../data/pos_report_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_report_logic.dart';
import '../logic/pos_report_providers.dart';
import 'pos_report_pdf.dart';
import 'pos_report_widgets.dart';
import 'pos_widgets.dart';

/// "Analysis": peak hours, best sellers and team insights for today, this week or this month. Jetpack's POSAnalyticsScreen.
class PosAnalyticsScreen extends ConsumerStatefulWidget {
  const PosAnalyticsScreen({super.key});

  @override
  ConsumerState<PosAnalyticsScreen> createState() => _PosAnalyticsScreenState();
}

class _PosAnalyticsScreenState extends ConsumerState<PosAnalyticsScreen> {
  PosPeriod _period = PosPeriod.today;
  bool _exporting = false;

  Future<void> _export(PosReport r) async {
    setState(() => _exporting = true);
    try {
      await sharePosAnalyticsPdf(context, r, store: ref.read(posAuthProvider).staff?.business.name ?? '', periodLabel: context.str(_period.labelKey), currency: ref.read(posCurrencyProvider));
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(posAnalyticsReportProvider(_period.value));
    final r = async.value;

    Widget kpi(String key, String value, String growth) => Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str(key), style: TextStyle(fontSize: 12, color: tk.text2)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
            const SizedBox(height: 2),
            GrowthChip(growth),
          ]),
        ),
      ),
    );

    final Widget body;
    if (r == null) {
      body = async.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'pos_posanalysisscreen_retry_button', onAction: () async => ref.invalidate(posAnalyticsReportProvider(_period.value)))
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 90, radius: 16), SizedBox(height: 12), SkeletonBox(height: 200, radius: 16), SizedBox(height: 12), SkeletonBox(height: 160, radius: 16)])));
    } else if (r.isEmpty) {
      body = FinanceMessage(icon: Icons.insights_outlined, title: context.str('pos_posanalysisscreen_noDataAvailable'));
    } else {
      final top = topSellers(r.bestItems, 10);
      final maxItem = top.isEmpty ? 0.0 : top.first.revenueRaw;
      final maxStaff = r.staff.fold(0.0, (m, s) => s.revenueRaw > m ? s.revenueRaw : m);
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Row(children: [
            kpi('pos_posanalysisscreen_revenue_label', r.revenue.revenue, r.revenue.revenueGrowth),
            const SizedBox(width: 8),
            kpi('pos_posanalysisscreen_kpi_orders', '${r.revenue.orders}', r.revenue.ordersGrowth),
            const SizedBox(width: 8),
            kpi('pos_posanalysisscreen_kpi_avg_ticket', r.revenue.avgTicket, r.revenue.avgTicketGrowth),
          ]),
          const SizedBox(height: 12),
          PosReportCard(
            title: context.str('pos_posanalysisscreen_peak_hours_title'),
            trailing: r.peak.peakHour.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(r.peak.peakHour, style: TextStyle(fontWeight: FontWeight.w800, color: context.primary)), if (r.peak.peakRevenue.isNotEmpty) Text('${context.str('pos_posanalysisscreen_peak_revenue_label')} ${r.peak.peakRevenue}', style: TextStyle(fontSize: 11.5, color: tk.text3))]),
            children: [HourlyBars(peak: r.peak)],
          ),
          if (r.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            PosReportCard(
              title: context.str('pos_posanalysisscreen_category_title'),
              subtitle: context.str('pos_posanalysisscreen_category_subtitle'),
              children: [for (final c in r.categories) ShareRow(name: c.name, value: c.revenue, share: shareOf(c.percentage), note: c.percentage, trailing: GrowthChip(c.growth, positive: c.isPositive))],
            ),
          ],
          if (top.isNotEmpty) ...[
            const SizedBox(height: 12),
            PosReportCard(
              title: context.str('pos_posanalysisscreen_best_sellers_title'),
              subtitle: context.str('pos_posanalysisscreen_best_sellers_subtitle'),
              children: [for (final i in top) ShareRow(name: i.name, value: i.revenue, share: maxItem <= 0 ? 0 : (i.revenueRaw / maxItem).clamp(0.0, 1.0), note: '${i.totalSold}${context.str('pos_posdashboardscreen_sold_suffix')}${i.category.isEmpty ? '' : '  ·  ${i.category}'}', trailing: GrowthChip(i.growth, positive: i.isPositive))],
            ),
          ],
          if (r.payments.breakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            PosReportCard(
              title: context.str('pos_posanalysisscreen_payment_title'),
              trailing: r.payments.totalAmount.isEmpty ? null : Text(r.payments.totalAmount, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
              children: [for (final p in r.payments.breakdown) ShareRow(name: p.name, value: p.amount, share: (p.percentage / 100).clamp(0.0, 1.0), note: p.percentageText)],
            ),
          ],
          if (r.staff.isNotEmpty) ...[
            const SizedBox(height: 12),
            PosReportCard(
              title: context.str('pos_posanalysisscreen_staff_title'),
              children: [for (final s in r.staff) ShareRow(name: s.name, value: s.revenue, share: maxStaff <= 0 ? 0 : (s.revenueRaw / maxStaff).clamp(0.0, 1.0), note: '${s.orders} ${context.str('pos_posanalysisscreen_kpi_orders')}${s.avgOrder.isEmpty ? '' : '  ·  ${context.str('pos_posanalysisscreen_kpi_avg_ticket')} ${s.avgOrder}'}')],
            ),
          ],
        ],
      );
    }

    return PosPage(
      title: context.str('pos_posanalysisscreen_top_bar_title'),
      back: Routes.posMore,
      actions: [
        if (r != null && !r.isEmpty) IconButton(onPressed: _exporting ? null : () => _export(r), tooltip: 'PDF', icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)) : const Icon(Icons.picture_as_pdf_outlined)),
      ],
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_posanalysisscreen_top_bar_subtitle'), style: TextStyle(color: tk.text2)))),
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
            for (final p in PosPeriod.values) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(context.str(p.labelKey)), selected: p == _period, onSelected: (_) => setState(() => _period = p))),
          ]),
        ),
        Expanded(child: RefreshIndicator(onRefresh: () async => ref.invalidate(posAnalyticsReportProvider(_period.value)), child: body)),
      ]),
    );
  }
}