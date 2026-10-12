import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../../home/ui/home_format.dart';
import '../data/pos_shift_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_logic.dart';
import '../logic/pos_shift_providers.dart';
import 'pos_widgets.dart';

/// "My Shift History": the staff member's past shifts, page by page. Jetpack's "shift_history".
class PosShiftHistoryScreen extends ConsumerWidget {
  const PosShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(posShiftHistoryProvider);
    final ctrl = ref.read(posShiftHistoryProvider.notifier);
    final items = st.items;
    final currency = ref.watch(posCurrencyProvider);

    final Widget body;
    if (st.showShimmer) {
      body = const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (st.showError) {
      body = FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_possessionhistoryscreen_retry', onAction: ctrl.refresh);
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      body = FinanceMessage(icon: Icons.history_rounded, title: context.str('pos_possessionhistoryscreen_no_session_history'), message: context.str('pos_possessionhistoryscreen_past_sessions_will_appear_here'));
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 500) ctrl.loadMore();
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i < items.length) return _ShiftCard(s: items[i], currency: currency);
            if (!st.hasMore && items.isNotEmpty) {
              return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(context.str('pos_possessionhistoryscreen_all_sessions_loaded', [items.length]), style: TextStyle(fontSize: 12.5, color: context.tk.text3))));
            }
            return ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);
          },
        ),
      );
    }

    return PosPage(title: context.str('pos_possessionhistoryscreen_my_shift_history'), back: Routes.posSessions, child: RefreshIndicator(onRefresh: ctrl.refresh, child: body));
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.s, required this.currency});

  final PosShift s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    String cash(double? v) => v == null ? '—' : money(currency, posAmountText(v));
    final diff = s.cashDiff;
    Widget cell(String key, String value, {Color? color}) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.str(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3)),
        const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color ?? tk.text1))),
      ]),
    );
    final when = [if (s.loginAt.isNotEmpty) posDateTime(context, s.loginAt), if (s.logoutAt.isNotEmpty) posDateTime(context, s.logoutAt)].join('  →  ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(s.terminalName.isEmpty ? '#${s.sessionId}' : s.terminalName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))),
              PosChip(s.isActive ? context.str('pos_possessionhistoryscreen_active') : s.status, s.isActive ? tk.success : tk.text3),
            ]),
            if (s.staffName.isNotEmpty) Text(s.staffName, style: TextStyle(color: tk.text2)),
            if (when.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(when, style: TextStyle(fontSize: 12.5, color: tk.text3))),
            const SizedBox(height: 12),
            Row(children: [
              cell('pos_posallsessionsscreen_opening', cash(s.openingCash)),
              cell('pos_possessiondetailscreen_info_closing_cash', cash(s.closingCash)),
              cell('pos_possessionhistoryscreen_cash_diff', diff == null ? '—' : '${diff > 0 ? '+' : ''}${cash(diff)}', color: diff == null ? null : (diff < 0 ? tk.danger : tk.success)),
            ]),
          ],
        ),
      ),
    );
  }
}