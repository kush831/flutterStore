import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../../splash/ui/brand_widgets.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_held.dart';
import '../logic/pos_report_logic.dart';
import '../logic/pos_report_providers.dart';
import 'pos_order_card.dart';
import 'pos_report_widgets.dart';
import 'pos_widgets.dart';

/// The first screen of POS: the shift at a glance, and the ways into selling. Jetpack's POSDashboardScreen.
/// Phone: one column. Tablet and browser: the store app's page header, then the hero beside the KPIs, a row of actions, and two columns of cards.
class PosDashboardScreen extends ConsumerWidget {
  const PosDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final async = ref.watch(posDashboardReportProvider);
    final r = async.value;
    final staff = ref.watch(posAuthProvider).staff;
    final held = ref.watch(posHeldCartsProvider);
    final terminal = ref.watch(posActiveSessionProvider).value?.terminalName ?? '';
    final brand = context.primary;
    final on = onColor(brand);
    final wide = !context.screen.isCompact;

    Future<void> refresh() async {
      ref.invalidate(posDashboardReportProvider);
      try {
        await ref.read(posDashboardReportProvider.future);
      } catch (_) {}
    }

    Widget action(IconData icon, String titleKey, String? subKey, VoidCallback onTap, {int badge = 0}) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon, color: brand, size: 26)),
            const SizedBox(height: 6),
            Text(context.str(titleKey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1, fontSize: 13)),
            if (subKey != null) Text(context.str(subKey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: tk.text3)),
          ]),
        ),
      ),
    );

    final Widget body;
    if (r == null) {
      final state = async.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('pos_posdashboardscreen_load_failed'), message: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'pos_posanalysisscreen_retry_button', onAction: refresh)
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 130, radius: 16), SizedBox(height: 12), SkeletonBox(height: 80, radius: 16), SizedBox(height: 12), SkeletonBox(height: 200, radius: 16)])));
      body = wide ? SizedBox(height: 420, child: state) : state; // the wide page scrolls as a whole, so the message needs a height of its own
    } else {
      final rev = r.revenue;
      final shift = r.shift;
      final active = queueActive(r.queue);

      final heroCard = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(context.str('pos_posdashboardscreen_today_s_revenue'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: on.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(rev.revenue.isEmpty ? '—' : rev.revenue, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: on))),
          if (rev.revenueGrowth.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${rev.revenueGrowth} ${context.str('pos_posdashboardscreen_vs_yesterday')}', style: TextStyle(color: on.withValues(alpha: 0.9), fontWeight: FontWeight.w600))),
        ]),
      );

      Widget kpiRow({required bool stretch, double gap = 8}) => Row(crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
        Expanded(child: PosStat(label: context.str('pos_posdashboardscreen_kpi_total_orders'), value: '${rev.orders}')),
        SizedBox(width: gap),
        Expanded(child: PosStat(label: context.str('pos_posdashboardscreen_kpi_avg_order'), value: rev.avgTicket.isEmpty ? '—' : rev.avgTicket)),
        SizedBox(width: gap),
        Expanded(child: PosStat(label: context.str('pos_posdashboardscreen_kpi_peak_hour'), value: r.peak.peakHour.isEmpty ? '—' : r.peak.peakHour)),
      ]);

      Widget actionsRow({required bool stretch, double gap = 8}) => Row(crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
        action(Icons.add_shopping_cart_rounded, 'pos_posdashboardscreen_action_new_sale', 'pos_posdashboardscreen_action_new_sale_subtitle', () => context.go(Routes.posProducts)),
        SizedBox(width: gap),
        action(Icons.receipt_long_outlined, 'pos_posdashboardscreen_action_orders', null, () => context.go(Routes.posOrders)),
        SizedBox(width: gap),
        action(Icons.point_of_sale_rounded, 'pos_posdashboardscreen_action_register', 'pos_posdashboardscreen_action_register_subtitle', () => context.go(Routes.posSessions)),
        SizedBox(width: gap),
        action(Icons.bookmarks_outlined, 'pos_posdashboardscreen_action_save_carts', 'pos_posdashboardscreen_action_manual_subtitle', () => context.push(Routes.posHeldCarts), badge: held.length),
      ]);

      final hourlyCard = PosReportCard(
        title: context.str('pos_posdashboardscreen_hourly_sales'),
        trailing: r.peak.peakHour.isEmpty ? null : PosChip('${context.str('pos_posdashboardscreen_peak_label')} ${r.peak.peakHour}', brand),
        children: [HourlyBars(peak: r.peak)],
      );

      final categoryCard = r.categories.isEmpty
          ? null
          : PosReportCard(
        title: context.str('pos_posdashboardscreen_category_performance'),
        trailing: Text('${r.categories.length}${context.str('pos_posdashboardscreen_categories_count_suffix')}', style: TextStyle(color: tk.text3, fontSize: 12)),
        children: [for (final c in r.categories) ShareRow(name: c.name.isEmpty ? context.str('pos_posdashboardscreen_category_fallback') : c.name, value: c.revenue, share: shareOf(c.percentage), note: c.percentage, trailing: GrowthChip(c.growth, positive: c.isPositive))],
      );

      final paymentCard = r.payments.breakdown.isEmpty
          ? null
          : PosReportCard(
        title: context.str('pos_posdashboardscreen_payment_split'),
        trailing: Text('${r.payments.breakdown.length}${context.str('pos_posdashboardscreen_payment_methods_count_suffix')}', style: TextStyle(color: tk.text3, fontSize: 12)),
        children: [
          for (final p in r.payments.breakdown) ShareRow(name: p.name.isEmpty ? context.str('pos_posdashboardscreen_payment_method_fallback') : p.name, value: p.amount, share: (p.percentage / 100).clamp(0.0, 1.0), note: p.percentageText),
          if (r.payments.totalAmount.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Text(context.str('pos_posdashboardscreen_total'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text3)), const Spacer(), Text(r.payments.totalAmount, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))])),
        ],
      );

      final topCard = r.bestItems.isEmpty
          ? null
          : PosReportCard(
        title: context.str('pos_posdashboardscreen_top_selling'),
        children: [for (final i in topSellers(r.bestItems, 5)) ShareRow(name: i.name.isEmpty ? context.str('pos_posdashboardscreen_item_fallback') : i.name, value: i.revenue, share: r.bestItems.first.revenueRaw <= 0 ? 0 : (i.revenueRaw / topSellers(r.bestItems, 1).first.revenueRaw).clamp(0.0, 1.0), note: '${i.totalSold}${context.str('pos_posdashboardscreen_sold_suffix')}${i.category.isEmpty ? '' : '  ·  ${i.category}'}', trailing: GrowthChip(i.growth, positive: i.isPositive))],
      );

      final queueCard = PosReportCard(
        title: context.str('pos_posdashboardscreen_order_queue'),
        subtitle: active == 0 ? context.str('pos_posdashboardscreen_order_queue_empty') : context.str('pos_posdashboardscreen_order_queue_active_count', [active]),
        trailing: TextButton(onPressed: () => context.push(Routes.posOrderQueue), child: Text(context.str('pos_posdashboardscreen_all_open'))),
        children: [
          Row(children: [
            for (final e in [(r.queue.waiting, 'pos_posdashboardscreen_queue_filter_waiting'), (r.queue.preparing, 'pos_posdashboardscreen_queue_filter_preparing'), (r.queue.ready, 'pos_posdashboardscreen_queue_filter_ready')])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: e.$1 > 0 ? brand.withValues(alpha: 0.1) : tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Column(children: [Text('${e.$1}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: e.$1 > 0 ? brand : tk.text3)), Text(context.str(e.$2), style: TextStyle(fontSize: 12, color: tk.text2))]),
                ),
              ),
          ]),
          for (final o in r.recentOrders.take(5)) Padding(padding: const EdgeInsets.only(top: 10), child: PosOrderCard(order: o)),
        ],
      );

      final shiftCard = shift == null
          ? null
          : Builder(builder: (context) {
        final balanced = shiftBalanced(shift);
        Widget row(String key, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))]));
        return PosReportCard(
          title: context.str('pos_posdashboardscreen_shift_summary'),
          children: [
            row('pos_posdashboardscreen_shift_opening', shift.openingCash),
            row('pos_posdashboardscreen_shift_current', shift.currentCash),
            row('pos_posdashboardscreen_shift_transactions', '${shift.transactions}'),
            Divider(height: 18, color: tk.border),
            row('pos_posdashboardscreen_expected_vs_actual', '${shift.expectedCash} / ${shift.actualCash}'),
            const SizedBox(height: 6),
            Row(children: [Icon(balanced ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 18, color: balanced ? tk.success : tk.danger), const SizedBox(width: 6), Expanded(child: Text(context.str(balanced ? 'pos_posdashboardscreen_shift_balanced' : 'pos_posdashboardscreen_shift_discrepancy'), style: TextStyle(fontWeight: FontWeight.w700, color: balanced ? tk.success : tk.danger)))]),
          ],
        );
      });

      if (!wide) {
        // phone: exactly the one column it was
        body = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            heroCard,
            const SizedBox(height: 12),
            kpiRow(stretch: false),
            const SizedBox(height: 12),
            actionsRow(stretch: false),
            const SizedBox(height: 12),
            hourlyCard,
            if (categoryCard != null) ...[const SizedBox(height: 12), categoryCard],
            if (paymentCard != null) ...[const SizedBox(height: 12), paymentCard],
            if (topCard != null) ...[const SizedBox(height: 12), topCard],
            const SizedBox(height: 12),
            queueCard,
            if (shiftCard != null) ...[const SizedBox(height: 12), shiftCard],
          ],
        );
      } else {
        // tablet and browser: the revenue hero beside the KPIs, the four actions in a row, then two columns of cards
        body = LayoutBuilder(builder: (context, box) {
          final side = box.maxWidth >= 640;
          final two = box.maxWidth >= 760;
          Widget stack(List<Widget> cards) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 16), cards[i]]]);
          final left = <Widget>[hourlyCard, ?categoryCard, ?topCard];
          final right = <Widget>[queueCard, ?shiftCard, ?paymentCard];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            side
                ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 5, child: heroCard), const SizedBox(width: 16), Expanded(flex: 7, child: kpiRow(stretch: true, gap: 12))]))
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heroCard, const SizedBox(height: 12), kpiRow(stretch: false)]),
            const SizedBox(height: 16),
            IntrinsicHeight(child: actionsRow(stretch: true, gap: 12)),
            const SizedBox(height: 16),
            if (two)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: stack(left)), const SizedBox(width: 16), Expanded(flex: 5, child: stack(right))])
            else
              stack([...left, ...right]),
          ]);
        });
      }
    }

    if (!wide) {
      return SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Expanded(child: Text(staff?.business.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: tk.text1))),
              PosChip(context.str('pos_posdashboardscreen_pos_mode_active'), tk.success),
            ]),
          ),
          Expanded(child: RefreshIndicator(color: brand, onRefresh: refresh, child: body)),
        ]),
      );
    }

    return AdaptivePage(
      title: staff?.business.name ?? '',
      subtitle: [context.str('pos_posdashboardscreen_nav_dashboard'), if (terminal.isNotEmpty) terminal].join(' · '),
      scroll: true,
      actions: [
        PosChip(context.str('pos_posdashboardscreen_pos_mode_active'), tk.success),
        IconButton(onPressed: refresh, style: IconButton.styleFrom(side: BorderSide(color: tk.border)), icon: Icon(Icons.refresh_rounded, color: tk.text1)),
      ],
      child: body,
    );
  }
}