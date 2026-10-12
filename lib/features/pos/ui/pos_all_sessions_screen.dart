import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../../home/ui/home_format.dart';
import '../data/pos_permission.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_models.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_logic.dart';
import '../logic/pos_shift_providers.dart';
import 'pos_widgets.dart';

/// The manager's view of every open shift, with a Force Transfer for the ones that are stuck. Jetpack's "all_sessions".
class PosAllSessionsScreen extends ConsumerStatefulWidget {
  const PosAllSessionsScreen({super.key});

  @override
  ConsumerState<PosAllSessionsScreen> createState() => _PosAllSessionsScreenState();
}

class _PosAllSessionsScreenState extends ConsumerState<PosAllSessionsScreen> {
  String? _transferringId;

  Future<void> _forceTransfer(PosManagerSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.admin_panel_settings_outlined, size: 38, color: ctx.primary),
        title: Text(ctx.str('pos_posallsessionsscreen_force_transfer')),
        content: Text([s.terminal, s.cashier].where((x) => x.isNotEmpty).join('  ·  '), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posterminalscreen_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posallsessionsscreen_force_transfer'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _transferringId = s.sessionId);
    try {
      // Jetpack sends the session's own terminal and device: the manager frees a stuck shift without moving it
      final message = await ref.read(posShiftRepositoryProvider).forceTransfer(ref.read(posBusinessIdProvider), sessionId: s.sessionId, terminalId: s.terminalId, deviceId: s.deviceId);
      ref.invalidate(posActiveSessionProvider);
      ref.invalidate(posTerminalProvider);
      await ref.read(posAllSessionsProvider.notifier).refresh();
      if (mounted && message.isNotEmpty) showAppSnack(context, message);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _transferringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final st = ref.watch(posAllSessionsProvider);
    final ctrl = ref.read(posAllSessionsProvider.notifier);
    final items = st.items;
    final currency = ref.watch(posCurrencyProvider);
    final canForce = ref.watch(posAuthProvider.select((s) => s.can(PosPerm.forceTransfer)));
    String m(num v) => money(currency, posAmountText(v.toDouble()));

    final Widget body;
    if (st.showShimmer) {
      body = const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (st.showError) {
      body = FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posanalysisscreen_retry_button', onAction: ctrl.refresh);
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      body = FinanceMessage(icon: Icons.groups_2_outlined, title: context.str('pos_posallsessionsscreen_no_active_sessions'));
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 500) ctrl.loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(children: [
              Expanded(child: PosStat(label: context.str('pos_posallsessionsscreen_active_sessions'), value: '${activeOf(items).length}', color: tk.success)),
              const SizedBox(width: 10),
              Expanded(child: PosStat(label: context.str('pos_posallsessionsscreen_total_in_drawers'), value: m(drawersTotal(items)))),
            ]),
            const SizedBox(height: 12),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionCard(s: s, money: (v) => m(posNum(v)), canForce: canForce, busy: _transferringId == s.sessionId, locked: _transferringId != null, onForce: () => _forceTransfer(s)),
              ),
            ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore),
          ],
        ),
      );
    }

    return PosPage(title: context.str('pos_posallsessionsscreen_title'), back: Routes.posSessions, child: RefreshIndicator(onRefresh: ctrl.refresh, child: body));
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.s, required this.money, required this.canForce, required this.busy, required this.locked, required this.onForce});

  final PosManagerSession s;
  final String Function(String) money;
  final bool canForce;
  final bool busy;
  final bool locked;
  final VoidCallback onForce;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget cell(String key, String value) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.str(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3)),
        const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
      ]),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(s.terminal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))),
              PosChip(s.isActive ? context.str('pos_possessiondetailscreen_status_active') : s.status, s.isActive ? tk.success : tk.text3),
            ]),
            if (s.cashier.isNotEmpty) Text(s.cashier, style: TextStyle(color: tk.text2)),
            if (s.loginAt.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(posDateTime(context, s.loginAt), style: TextStyle(fontSize: 12.5, color: tk.text3))),
            const SizedBox(height: 12),
            Row(children: [
              cell('pos_posallsessionsscreen_opening', money(s.openingCash)),
              cell('pos_posallsessionsscreen_cash_sales', money(s.cashSales)),
              cell('pos_posallsessionsscreen_expected', money(s.expectedDrawer)),
            ]),
            if (canForce && s.isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: locked ? null : onForce,
                  icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  label: Text(context.str(busy ? 'pos_posallsessionsscreen_transferring' : 'pos_posallsessionsscreen_force_transfer')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}