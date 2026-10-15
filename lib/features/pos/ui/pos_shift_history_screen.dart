import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
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
/// Phone: cards in one column. Tablet: cards in two columns. Wide tablet and browser: the store app's page header and a table.
class PosShiftHistoryScreen extends ConsumerWidget {
  const PosShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final st = ref.watch(posShiftHistoryProvider);
    final ctrl = ref.read(posShiftHistoryProvider.notifier);
    final items = st.items;
    final currency = ref.watch(posCurrencyProvider);
    final title = context.str('pos_possessionhistoryscreen_my_shift_history');

    String cash(double? v) => v == null ? '—' : money(currency, posAmountText(v));

    // the states that are the same on every width
    Widget? state() {
      if (st.showShimmer) return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_possessionhistoryscreen_retry', onAction: ctrl.refresh);
      if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.history_rounded, title: context.str('pos_possessionhistoryscreen_no_session_history'), message: context.str('pos_possessionhistoryscreen_past_sessions_will_appear_here'));
      return null;
    }

    Widget scrolling(Widget child) => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(onRefresh: ctrl.refresh, child: child),
    );

    final endNote = (!st.hasMore && items.isNotEmpty)
        ? Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(context.str('pos_possessionhistoryscreen_all_sessions_loaded', [items.length]), style: TextStyle(fontSize: 12.5, color: tk.text3))))
        : ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);

    // ── cards: one column on a phone, two on a tablet ────────────────────────
    Widget cards(int cols, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 32)}) {
      final rows = (items.length / cols).ceil();
      return scrolling(
        ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: rows + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == rows) return endNote;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 10),
                Expanded(child: i * cols + c < items.length ? _ShiftCard(s: items[i * cols + c], currency: currency) : const SizedBox.shrink()),
              ],
            ]);
          },
        ),
      );
    }

    // ── the table: browser and wide tablet ───────────────────────────────────
    Widget table() {
      Widget head(String key, {int flex = 1, TextAlign align = TextAlign.start}) => Expanded(flex: flex, child: Text(context.str(key), textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3)));
      Widget cell(String text, {int flex = 1, TextAlign align = TextAlign.start, bool bold = false, Color? color}) => Expanded(flex: flex, child: Text(text, textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? tk.text1)));
      String when(String raw) => raw.isEmpty ? '—' : posDateTime(context, raw);

      Widget row(PosShift s) {
        final diff = s.cashDiff;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border))),
          child: Row(children: [
            cell(s.terminalName.isEmpty ? '#${s.sessionId}' : s.terminalName, flex: 14, bold: true),
            cell(s.staffName, flex: 12, color: tk.text2),
            cell(when(s.loginAt), flex: 18, color: tk.text2),
            cell(when(s.logoutAt), flex: 18, color: tk.text2),
            cell(cash(s.openingCash), flex: 10, align: TextAlign.end),
            cell(cash(s.closingCash), flex: 10, align: TextAlign.end),
            cell(diff == null ? '—' : '${diff > 0 ? '+' : ''}${cash(diff)}', flex: 11, align: TextAlign.end, bold: true, color: diff == null ? null : (diff < 0 ? tk.danger : tk.success)),
            Expanded(flex: 12, child: Align(alignment: AlignmentDirectional.centerEnd, child: PosChip(s.isActive ? context.str('pos_possessionhistoryscreen_active') : s.status, s.isActive ? tk.success : tk.text3))),
          ]),
        );
      }

      return scrolling(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Container(
                  color: tk.sunken,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    head('pos_possessionhistoryscreen_col_terminal', flex: 14),
                    head('pos_possessionhistoryscreen_col_staff', flex: 12),
                    head('pos_possessionhistoryscreen_col_started', flex: 18),
                    head('pos_possessionhistoryscreen_col_ended', flex: 18),
                    head('pos_posallsessionsscreen_opening', flex: 10, align: TextAlign.end),
                    head('pos_possessiondetailscreen_info_closing_cash', flex: 10, align: TextAlign.end),
                    head('pos_possessionhistoryscreen_cash_diff', flex: 11, align: TextAlign.end),
                    head('pos_possessionhistoryscreen_col_status', flex: 12, align: TextAlign.end),
                  ]),
                ),
                for (final s in items) row(s),
              ]),
            ),
            endNote,
          ],
        ),
      );
    }

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      return PosPage(title: title, back: Routes.posSessions, child: state() ?? cards(1));
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    return AdaptivePage(
      title: title,
      subtitle: items.isEmpty ? null : context.str('pos_possessionhistoryscreen_all_sessions_loaded', [items.length]),
      fallbackRoute: Routes.posSessions,
      child: LayoutBuilder(builder: (context, box) => state() ?? (box.maxWidth >= 860 ? table() : cards(2, padding: const EdgeInsets.fromLTRB(0, 4, 0, 32)))),
    );
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