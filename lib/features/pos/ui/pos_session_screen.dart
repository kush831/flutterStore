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
import '../../home/ui/home_format.dart';
import '../../splash/ui/brand_widgets.dart';
import '../data/pos_models.dart';
import '../data/pos_permission.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// "Sessions" in the POS menu: the open shift with its numbers, and the actions that manage it. Jetpack's POSSessionScreen.
/// Phone: one column. Tablet and browser: the store app's page header, the hero beside the live stats, and the actions as a grid of tiles.
class PosSessionScreen extends ConsumerWidget {
  const PosSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final async = ref.watch(posActiveSessionProvider);
    final session = async.value;
    final hasSession = session != null && session.isActive;
    final currency = ref.watch(posCurrencyProvider);
    final staffName = ref.watch(posAuthProvider.select((s) => s.staff?.name ?? ''));
    final canViewAll = ref.watch(posAuthProvider.select((s) => s.can(PosPerm.viewAllSessions)));

    Future<void> refresh() async {
      ref.invalidate(posActiveSessionProvider);
      try {
        await ref.read(posActiveSessionProvider.future);
      } catch (_) {}
    }

    // ── loading and failing: the same words on every width ───────────────────
    if (async.isLoading && async.value == null) {
      const skeleton = Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 150, radius: 16), SizedBox(height: 12), SkeletonBox(height: 90, radius: 16), SizedBox(height: 12), SkeletonBox(height: 200, radius: 16)])));
      return wide ? AdaptivePage(title: context.str('pos_possessiondashboardscreen_session'), child: skeleton) : PosPage(title: context.str('pos_possessiondashboardscreen_session'), child: skeleton);
    }
    if (async.hasError && async.value == null) {
      final failed = Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 12),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: refresh, child: Text(context.str('pos_posterminalscreen_try_again'))),
        ]),
      );
      return wide ? AdaptivePage(title: context.str('pos_possessiondashboardscreen_session'), child: Center(child: failed)) : PosPage(title: context.str('pos_possessiondashboardscreen_session'), child: failed);
    }

    final actions = <_Action>[
      if (hasSession) ...[
        _Action(Icons.stop_circle_outlined, 'pos_possessiondashboardscreen_close_session', 'pos_possessiondashboardscreen_end_shift_reconcile_cash_drawer', Routes.posCloseSession, danger: true),
        _Action(Icons.swap_horiz_rounded, 'pos_possessiondashboardscreen_handover_shift', 'pos_possessiondashboardscreen_pass_terminal_to_incoming_staff', Routes.posHandover),
        _Action(Icons.sync_alt_rounded, 'pos_possessiondashboardscreen_transfer_terminal', 'pos_possessiondashboardscreen_move_session_to_working_terminal', Routes.posTransfer),
      ],
      _Action(Icons.history_rounded, 'pos_possessiondashboardscreen_my_shift_history', 'pos_possessiondashboardscreen_your_past_shifts_summaries', Routes.posShiftHistory),
      if (canViewAll) _Action(Icons.groups_2_outlined, 'pos_possessiondashboardscreen_all_sessions', 'pos_possessiondashboardscreen_all_active_sessions_force_transfer', Routes.posAllSessions),
    ];

    final ordersStat = hasSession ? PosStat(label: context.str('pos_possessiondashboardscreen_stat_orders'), value: session.totalOrders.isEmpty ? '0' : session.totalOrders) : null;
    final cashStat = hasSession ? PosStat(label: context.str('pos_possessiondashboardscreen_stat_cash_sales'), value: money(currency, session.totalCashSales.isEmpty ? '0' : session.totalCashSales)) : null;

    Widget grid(int cols) => LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final a in actions) SizedBox(width: w, child: _ActionCard(a: a, onTap: () => context.push(a.route)))]);
    });

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (hasSession) _SessionHero(s: session, currency: currency) else const _NoSession(),
          if (hasSession) ...[
            const SizedBox(height: 18),
            const _Label('pos_possessiondashboardscreen_live_stats'),
            Row(children: [Expanded(child: ordersStat!), const SizedBox(width: 10), Expanded(child: cashStat!)]),
          ],
          const SizedBox(height: 18),
          const _Label('pos_possessiondashboardscreen_manage_session'),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 520 ? 2 : 1;
            final w = (box.maxWidth - 10 * (cols - 1)) / cols;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final a in actions) SizedBox(width: w, child: _ActionCard(a: a, onTap: () => context.push(a.route)))]);
          }),
        ],
      );
      return PosPage(title: context.str('pos_possessiondashboardscreen_session'), child: RefreshIndicator(onRefresh: refresh, child: body));
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    final body = LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 700;
      final cols = box.maxWidth >= 900 ? 3 : 2;
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (!hasSession)
              Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 560), child: _NoSession()))
            else if (side)
            // the hero beside the live stats
              IntrinsicHeight(
                child: PosEqualRow(children: [
                  Expanded(flex: 6, child: _SessionHero(s: session, currency: currency)),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: ordersStat!), const SizedBox(height: 12), Expanded(child: cashStat!)])),
                ]),
              )
            else ...[
                _SessionHero(s: session, currency: currency),
                const SizedBox(height: 12),
                PosEqualRow(children: [Expanded(child: ordersStat!), const SizedBox(width: 12), Expanded(child: cashStat!)]),
              ],
            const SizedBox(height: 24),
            const _Label('pos_possessiondashboardscreen_manage_session'),
            grid(cols),
          ],
        ),
      );
    });

    return AdaptivePage(
      title: context.str('pos_possessiondashboardscreen_session'),
      subtitle: hasSession ? [if (session.terminalName.isNotEmpty) session.terminalName, if (staffName.isNotEmpty) staffName].join(' · ') : null,
      actions: [if (hasSession) PosChip(context.str('pos_possessiondashboardscreen_active_session'), tk.success)],
      child: body,
    );
  }
}

class _Action {
  const _Action(this.icon, this.titleKey, this.subtitleKey, this.route, {this.danger = false});

  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final String route;
  final bool danger;
}

class _Label extends StatelessWidget {
  const _Label(this.textKey);

  final String textKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(context.str(textKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.tk.text3)),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.a, required this.onTap});

  final _Action a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = a.danger ? tk.danger : context.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(a.icon, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.str(a.titleKey), style: TextStyle(fontWeight: FontWeight.w800, color: a.danger ? tk.danger : tk.text1)),
                Text(context.str(a.subtitleKey), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.3)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: tk.text3),
          ]),
        ),
      ),
    );
  }
}

class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.s, required this.currency});

  final PosActiveSession s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);
    final expected = expectedCash(s.openingCash, s.totalCashSales);
    Widget cell(String labelKey, String value) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.str(labelKey), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: on.withValues(alpha: 0.8))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: on))),
      ]),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: on.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(50)), child: Text(context.str('pos_possessiondashboardscreen_active_session'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: on))),
            const Spacer(),
            Text(formatLength(sessionLength(s.loginAt, DateTime.now())), style: TextStyle(fontWeight: FontWeight.w700, color: on)),
          ]),
          const SizedBox(height: 10),
          Text(s.terminalName.isEmpty ? context.str('pos_possessiondashboardscreen_counter_default') : s.terminalName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: on)),
          if (s.loginAt.isNotEmpty) Text(context.str('pos_possessiondashboardscreen_opened_at', [posDateTime(context, s.loginAt)]), style: TextStyle(fontSize: 12.5, color: on.withValues(alpha: 0.85))),
          const SizedBox(height: 16),
          Row(children: [cell('pos_possessiondashboardscreen_opening_cash', money(currency, s.openingCash.isEmpty ? '0' : s.openingCash)), cell('pos_possessiondashboardscreen_expected_cash', money(currency, posAmountText(expected)))]),
        ],
      ),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
      child: Column(children: [
        Icon(Icons.desktop_access_disabled_outlined, size: 48, color: tk.text3),
        const SizedBox(height: 12),
        Text(context.str('pos_possessiondashboardscreen_no_active_session'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
        const SizedBox(height: 6),
        Text(context.str('pos_possessiondashboardscreen_open_a_new_session_to_start_taking_orders'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
        const SizedBox(height: 4),
        Text(context.str('pos_possessiondashboardscreen_pick_a_terminal_enter_opening_cash'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: tk.text3)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => context.go(Routes.posOpenSession), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), child: Text(context.str('pos_possessiondashboardscreen_open_new_session'))),
      ]),
    );
  }
}