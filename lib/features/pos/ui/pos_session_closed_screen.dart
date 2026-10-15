import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_shift_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_exit.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// The result of a closed shift. Jetpack's "pos_session_closed". Back does not return to the Close screen.
/// Phone: one column. Tablet and browser: one card in the middle, the summary on the left and the cash result with the buttons on the right.
class PosSessionClosedScreen extends ConsumerWidget {
  const PosSessionClosedScreen({super.key, required this.result});

  final PosCloseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final currency = ref.watch(posCurrencyProvider);
    String m(double v) => money(currency, posAmountText(v));
    final status = cashStatus(result.cashDifference);
    final sc = cashStatusColor(context, status);

    Widget row(String key, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: tk.text1))]),
    );

    final check = Center(child: Container(width: 76, height: 76, decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 44, color: tk.success)));
    final title = Text(context.str('pos_posclosesessionscreen_session_closed_title'), textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1));
    final subtitle = Text(context.str('pos_posclosesessionscreen_session_closed_successfully'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2));

    final summaryLabel = Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(context.str('pos_possessionhistoryscreen_shift_summary'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

    final summary = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
          row('pos_posclosesessionscreen_total_orders', '${result.totalOrders}'),
          Divider(height: 1, color: tk.border),
          row('pos_possessionhistoryscreen_total_revenue', m(result.totalRevenue)),
          Divider(height: 1, color: tk.border),
          row('pos_posclosesessionscreen_cash_sales', m(result.totalCashSales)),
          Divider(height: 1, color: tk.border),
          row('pos_possessiondetailscreen_info_opening_cash', m(result.openingCash)),
          Divider(height: 1, color: tk.border),
          row('pos_possessiondetailscreen_info_closing_cash', m(result.closingCash), bold: true),
        ]),
      ),
    );

    final cashResult = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: sc.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: sc.withValues(alpha: 0.35))),
      child: Row(children: [
        Icon(status == CashStatus.balanced ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: sc),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str(cashStatusKey(status)), style: TextStyle(fontWeight: FontWeight.w800, color: sc)),
            Text(status == CashStatus.balanced ? context.str('pos_posdashboardscreen_shift_balanced') : m(result.cashDifference.abs()), style: TextStyle(fontSize: 12.5, color: tk.text2)),
          ]),
        ),
      ]),
    );

    final startButton = FilledButton(onPressed: () => context.go(Routes.posOpenSession), style: FilledButton.styleFrom(minimumSize: const Size(0, 54)), child: Text(context.str('pos_posclosesessionscreen_start_new_session')));
    final logoutButton = OutlinedButton(onPressed: () => posExit(context, ref), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), child: Text(context.str('pos_possessionloginscreen_logout')));

    // ── the content: one column, or two inside a card ────────────────────────
    final Widget content;
    if (!wide) {
      content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [check, const SizedBox(height: 16), title, const SizedBox(height: 6), subtitle, const SizedBox(height: 24), summaryLabel, summary, const SizedBox(height: 14), cashResult, const SizedBox(height: 26), startButton, const SizedBox(height: 10), logoutButton],
      );
    } else {
      content = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                child: LayoutBuilder(builder: (context, box) {
                  final two = box.maxWidth >= 560;
                  final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summaryLabel, summary]);
                  final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cashResult, const SizedBox(height: 18), startButton, const SizedBox(height: 10), logoutButton]);
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    check,
                    const SizedBox(height: 14),
                    title,
                    const SizedBox(height: 6),
                    subtitle,
                    const SizedBox(height: 26),
                    if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 24), Expanded(child: right)]) else ...[left, const SizedBox(height: 16), right],
                  ]);
                }),
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.posOpenSession);
      },
      child: Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(child: wide ? content : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: content))),
      ),
    );
  }
}