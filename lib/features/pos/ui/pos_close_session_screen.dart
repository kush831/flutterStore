import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../../splash/ui/brand_widgets.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// End the shift: count the cash, confirm, and see the result. Jetpack's "close_session".
class PosCloseSessionScreen extends ConsumerStatefulWidget {
  const PosCloseSessionScreen({super.key});

  @override
  ConsumerState<PosCloseSessionScreen> createState() => _PosCloseSessionScreenState();
}

class _PosCloseSessionScreenState extends ConsumerState<PosCloseSessionScreen> {
  final _counted = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  Future<void> _confirm(PosActiveSession s, double expected, String currency) async {
    FocusScope.of(context).unfocus();
    final diff = cashDifference(_counted.text, expected);
    final status = cashStatus(diff);
    String m(double v) => money(currency, posAmountText(v));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tk = ctx.tk;
        Widget row(String key, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(ctx.str(key), style: TextStyle(color: tk.text2))), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))]),
        );
        return AlertDialog(
          icon: Icon(Icons.stop_circle_outlined, size: 38, color: tk.danger),
          title: Text(ctx.str('pos_posclosesessionscreen_close_session_question')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            row('pos_posclosesessionscreen_counted_cash', m(posNum(_counted.text))),
            row('pos_possessiondashboardscreen_expected_cash', m(expected)),
            const SizedBox(height: 8),
            PosChip(ctx.str(cashStatusKey(status)), cashStatusColor(ctx, status)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posheldcartsscreen_cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posclosesessionscreen_confirm_close'))),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(posShiftRepositoryProvider).closeSession(ref.read(posBusinessIdProvider), sessionId: s.id, closingCash: _counted.text);
      ref.invalidate(posActiveSessionProvider);
      ref.read(posCartProvider.notifier).clear();
      if (!mounted) return;
      context.go(Routes.posSessionClosed, extra: result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(posActiveSessionProvider);
    final s = async.value;
    final currency = ref.watch(posCurrencyProvider);
    String m(double v) => money(currency, posAmountText(v));

    final Widget body;
    if (s == null || !s.isActive) {
      body = Center(
        child: async.isLoading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.str('pos_posclosesessionscreen_session_data_not_available'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text2)),
        ),
      );
    } else {
      final expected = expectedCash(s.openingCash, s.totalCashSales);
      final valid = cashValid(_counted.text);
      final status = cashStatus(cashDifference(_counted.text, expected));
      final brand = context.primary;
      final on = onColor(brand);

      Widget row(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))]),
      );

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.str('pos_posclosesessionscreen_in_drawer'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: on.withValues(alpha: 0.8))),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(m(expected), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: on))),
              Text(context.str('pos_possessiondashboardscreen_expected_cash'), style: TextStyle(fontSize: 12, color: on.withValues(alpha: 0.85))),
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(children: [
                row('pos_posclosesessionscreen_total_orders', s.totalOrders.isEmpty ? '0' : s.totalOrders),
                Divider(height: 1, color: tk.border),
                row('pos_possessiondetailscreen_info_opening_cash', m(posNum(s.openingCash))),
                Divider(height: 1, color: tk.border),
                row('pos_posclosesessionscreen_cash_sales', m(posNum(s.totalCashSales))),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(context.str('pos_posclosesessionscreen_counted_cash'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
          TextField(
            controller: _counted,
            enabled: !_busy,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(prefixText: currency.isEmpty ? null : '$currency ', hintText: '0'),
          ),
          if (valid) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: PosChip(status == CashStatus.balanced ? context.str(cashStatusKey(status)) : '${context.str(cashStatusKey(status))}  ·  ${m(cashDifference(_counted.text, expected).abs())}', cashStatusColor(context, status))),
          ],
          if (_error != null) ...[const SizedBox(height: 14), PosErrorBox(_error!)],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: (valid && !_busy) ? () => _confirm(s, expected, currency) : null,
            style: FilledButton.styleFrom(backgroundColor: tk.danger, minimumSize: const Size(0, 54)),
            child: _busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('pos_posclosesessionscreen_close_closing'))])
                : Text(context.str('pos_posclosesessionscreen_close_session')),
          ),
        ],
      );
    }

    return PosPage(title: context.str('pos_posclosesessionscreen_close_session'), back: Routes.posSessions, child: body);
  }
}