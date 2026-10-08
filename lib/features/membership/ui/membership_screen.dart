import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/membership_models.dart';
import '../data/membership_repository.dart';
import '../logic/membership_logic.dart';
import 'membership_pay_sheet.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  Future<void> _refresh() async {
    ref.invalidate(membershipProvider);
    try {
      await ref.read(membershipProvider.future);
    } catch (_) {} // the error shows on screen
  }

  Future<void> _subscribe(MembershipPlan plan, MembershipData data, String currency) async {
    final message = await showMembershipPay(context, plan: plan, options: data.options, currency: currency);
    if (message == null || !mounted) return;
    // the store is subscribed: nothing should send it back here
    await ref.read(appPrefsProvider).setMembershipEnabled(false);
    ref.invalidate(membershipProvider);
    ref.read(dashboardProvider.notifier).refresh(); // the MemberShip badge and popup on Home go away
    if (!mounted) return;
    showAppSnack(context, message.isEmpty ? context.str('membership_membershipscreen_success') : message);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final async = ref.watch(membershipProvider);
    final data = async.value;
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));

    final Widget body;
    if (data != null) {
      body = data.plans.isEmpty
          ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(Icons.workspace_premium_outlined, size: 56, color: tk.text3),
          const SizedBox(height: 14),
          Text(context.str('membership_membershipscreen_no_plans'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
        ]),
      )
          : _Plans(data: data, currency: currency, onSubscribe: (p) => _subscribe(p, data, currency));
    } else if (async.hasError) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: _refresh, child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      body = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 190, radius: 16), SizedBox(height: 12), SkeletonBox(height: 190, radius: 16)]));
    }

    return SubPage(
      title: context.str('settings_settings_row_memberShip'),
      fallbackRoute: Routes.home, // landing here straight from login: the arrow goes Home
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(compact ? 16 : 0, 8, compact ? 16 : 0, 32),
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(context.str('settings_settings_row_memberShipDesc'), style: TextStyle(fontSize: 14, color: tk.text2))),
            body,
          ],
        ),
      ),
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data, required this.currency, required this.onSubscribe});

  final MembershipData data;
  final String currency;
  final ValueChanged<MembershipPlan> onSubscribe;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    const gap = 12.0;
    final wide = box.maxWidth >= 760;
    final perRow = wide ? data.plans.length.clamp(1, 3) : 1;
    final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var i = 0; i < data.plans.length; i++)
          SizedBox(
            width: w,
            child: _PlanCard(
              plan: data.plans[i],
              currency: currency,
              recommended: isRecommended(i, data.plans.length, active: data.plans[i].active),
              onSubscribe: () => onSubscribe(data.plans[i]),
            ),
          ),
      ],
    );
  });
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.currency, required this.recommended, required this.onSubscribe});

  final MembershipPlan plan;
  final String currency;
  final bool recommended;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final parts = periodParts(plan.period);
    final period = parts.key.isEmpty ? plan.period : context.str(parts.key, parts.n == null ? const [] : [parts.n]);

    Widget feature(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_rounded, size: 18, color: tk.success),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: tk.text1, height: 1.3))),
      ]),
    );

    Widget badge(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: recommended ? context.primary : tk.border, width: recommended ? 1.8 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(plan.heading, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1))),
            if (plan.active) badge(context.str('membership_membershipscreen_current_plan'), tk.success.withValues(alpha: 0.14), tk.success),
            if (recommended) badge(context.str('membership_membershipscreen_recommended'), context.primary, Colors.white),
          ]),
          if (plan.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(plan.description, style: TextStyle(color: tk.text2, height: 1.4))),
          const SizedBox(height: 14),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text(money(currency, plan.price), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: tk.text1)),
            if (period.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('/ $period', style: TextStyle(fontSize: 14, color: tk.text2))),
          ]),
          const SizedBox(height: 10),
          if (plan.orders > 0) feature(context.str('membership_membershipscreen_orders_included', [plan.orders])),
          if (plan.hasMaxAmount) feature(context.str('membership_membershipscreen_max_order_value', [money(currency, plan.maxAmount)])),
          const SizedBox(height: 12),
          plan.active
              ? FilledButton(onPressed: null, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('membership_membershipscreen_current_plan')))
              : (recommended
              ? FilledButton(onPressed: onSubscribe, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('membership_membershipscreen_subscribe')))
              : OutlinedButton(onPressed: onSubscribe, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('membership_membershipscreen_subscribe')))),
        ],
      ),
    );
  }
}