import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// Pass the terminal to the next staff member: they type their phone and PIN. Jetpack's "handover_shift".
class PosHandoverScreen extends ConsumerStatefulWidget {
  const PosHandoverScreen({super.key});

  @override
  ConsumerState<PosHandoverScreen> createState() => _PosHandoverScreenState();
}

class _PosHandoverScreenState extends ConsumerState<PosHandoverScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit(String sessionId, String openingCash, double closing) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(posShiftRepositoryProvider).handover(handoverFields(
        businessId: ref.read(posBusinessIdProvider),
        sessionId: sessionId,
        phone: _phone.text,
        pin: _pin.text,
        openingCash: openingCash,
        closingCash: closing,
      ));
      ref.invalidate(posActiveSessionProvider); // this shift now belongs to the incoming staff member
      if (!mounted) return;
      if (message.isNotEmpty) showAppSnack(context, message);
      context.canPop() ? context.pop() : context.go(Routes.posSessions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(posActiveSessionProvider);
    final s = async.value;
    final staff = ref.watch(posAuthProvider).staff;
    final currency = ref.watch(posCurrencyProvider);
    String m(double v) => money(currency, posAmountText(v));

    Widget label(String key) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

    final Widget body;
    if (s == null || !s.isActive) {
      body = Center(
        child: async.isLoading
            ? const CircularProgressIndicator()
            : Padding(padding: const EdgeInsets.all(32), child: Text(context.str('pos_posclosesessionscreen_session_data_not_available'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text2))),
      );
    } else {
      final closing = expectedCash(s.openingCash, s.totalCashSales);
      final ready = handoverReady(_phone.text, _pin.text) && !_busy;
      Widget row(String key, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: tk.text1))]),
      );

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          label('pos_poshandoverscreen_outgoing'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(staff?.name ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
                const SizedBox(height: 2),
                Text('${context.str('pos_poshandoverscreen_session_prefix')}${s.id}', style: TextStyle(color: tk.text2)),
                Text('${context.str('pos_poshandoverscreen_terminal_stays_prefix')}${s.terminalName}', style: TextStyle(fontSize: 12.5, color: tk.text3)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          label('pos_poshandoverscreen_cash_reconciliation'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(children: [
                row('pos_posdashboardscreen_shift_opening', m(posNum(s.openingCash))),
                Divider(height: 1, color: tk.border),
                row('pos_posclosesessionscreen_cash_sales', m(posNum(s.totalCashSales))),
                Divider(height: 1, color: tk.border),
                row('pos_poshandoverscreen_closing_cash', m(closing), bold: true),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          label('pos_poshandoverscreen_incoming_staff'),
          TextField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(hintText: context.str('pos_poshandoverscreen_phone_number')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => ready ? _submit(s.id, s.openingCash, closing) : null,
            decoration: InputDecoration(hintText: context.str('pos_poshandoverscreen_4_digit_pin'), counterText: ''),
          ),
          if (_error != null) ...[const SizedBox(height: 14), PosErrorBox(_error!)],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: ready ? () => _submit(s.id, s.openingCash, closing) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
            child: _busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('pos_poshandoverscreen_processing'))])
                : Text(context.str('pos_poshandoverscreen_complete_handover')),
          ),
        ],
      );
    }

    return PosPage(title: context.str('pos_poshandoverscreen_shift_handover'), back: Routes.posSessions, child: body);
  }
}