import 'package:cached_network_image/cached_network_image.dart';
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
import '../data/pos_checkout_models.dart';
import '../data/pos_checkout_repository.dart';
import '../data/pos_repository.dart';
import '../data/pos_sale_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_checkout_logic.dart';
import '../logic/pos_order.dart';
import '../logic/pos_payment_logic.dart';
import '../logic/pos_sale.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// How the customer pays, and the button that places the order. Jetpack's "pos_payment_screen".
class PosPaymentScreen extends ConsumerStatefulWidget {
  const PosPaymentScreen({super.key});

  @override
  ConsumerState<PosPaymentScreen> createState() => _PosPaymentScreenState();
}

class _PosPaymentScreenState extends ConsumerState<PosPaymentScreen> {
  String? _methodId;
  double? _cash; // the cash received
  final _custom = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _pay(PosCartQuote quote, PosPaymentMethod method, double total, String totalText) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final kind = payKind(method.name);
    final choices = ref.read(posOrderProvider);
    final staff = ref.read(posAuthProvider).staff;
    final services = staff?.business.serviceTypes ?? const [];
    final service = services.where((s) => s.id == choices.serviceTypeId).firstOrNull ?? services.firstOrNull;
    final session = await ref.read(posActiveSessionProvider.future);
    final received = kind == PayKind.cash ? _cash : null;
    final change = received == null ? null : changeDue(received, total);
    try {
      final placed = await ref.read(posCheckoutRepositoryProvider).placeOrder(placeOrderBody(
        cartId: quote.cartId,
        methodId: method.id,
        sessionId: session?.id ?? '',
        orderType: orderTypeKey(service?.name ?? ''),
        kind: kind,
        cashReceived: received,
        change: change,
        promoCode: choices.promoCode,
        customerName: choices.customer.walkIn ? '' : choices.customer.name,
        customerPhone: choices.customer.walkIn ? '' : choices.customer.phone,
      ));
      ref.read(posLastSaleProvider.notifier).set(PosLastSale(
        orderId: placed.orderId,
        orderNumber: placed.orderNumber,
        methodName: method.name,
        cashReceived: received,
        changeDue: change,
        totalText: totalText,
        customerPhone: choices.customer.walkIn ? '' : choices.customer.phone,
      ));
      ref.read(posCartProvider.notifier).clear(); // the sale is done
      ref.read(posOrderProvider.notifier).reset();
      ref.invalidate(posActiveSessionProvider); // the shift's orders and cash sales have moved
      if (!mounted) return;
      context.go(Routes.posOrderSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider)); // a failed answer may still have placed the order: check Orders before retrying
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final quote = ref.watch(posQuoteProvider).value;
    final currency = ref.watch(posCurrencyProvider);
    String m(double v) => money(currency, posAmountText(v));

    // came here with nothing priced (a page reload, an emptied cart): back to the cart
    if (quote == null || quote.cartId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.posCart);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = grandTotal(quote);
    final totalText = quote.totalText.isNotEmpty ? quote.totalText : m(total);
    final method = quote.methods.where((x) => x.id == _methodId).firstOrNull;
    final kind = method == null ? null : payKind(method.name);
    final effectiveCash = _cash ?? 0;
    final canPay = method != null && !_busy && (kind != PayKind.cash || cashEnough(effectiveCash, total));

    Widget label(String key) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

    IconData iconOf(PayKind k) => switch (k) {
      PayKind.cash => Icons.payments_outlined,
      PayKind.card => Icons.credit_card_rounded,
      PayKind.upi => Icons.qr_code_2_rounded,
      PayKind.other => Icons.account_balance_wallet_outlined,
    };
    String subOf(PayKind k) => context.str(switch (k) {
      PayKind.cash => 'pos_pospaymentscreen_method_cash_sub',
      PayKind.card => 'pos_pospaymentscreen_method_card_sub',
      PayKind.upi => 'pos_pospaymentscreen_method_upi_sub',
      PayKind.other => 'pos_pospaymentscreen_method_other_sub',
    });

    Widget details() {
      switch (kind) {
        case PayKind.cash:
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.str('pos_pospaymentscreen_cash_received'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final q in kQuickCash)
                  ChoiceChip(
                    label: Text(m(q.toDouble())),
                    selected: _cash == q.toDouble(),
                    onSelected: _busy ? null : (_) => setState(() {
                      _cash = q.toDouble();
                      _custom.clear();
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _custom,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (v) => setState(() => _cash = double.tryParse(v.trim())),
                decoration: InputDecoration(hintText: context.str('pos_pospaymentscreen_cash_enter_amount'), prefixText: currency.isEmpty ? null : '$currency '),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(context.str('pos_pospaymentscreen_change_due'), style: TextStyle(color: tk.text2))),
                Text(m(changeDue(effectiveCash, total)), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cashEnough(effectiveCash, total) ? tk.success : tk.text3)),
              ]),
              if (_cash != null && !cashEnough(effectiveCash, total)) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.str('pos_payment_cash_short'), style: TextStyle(fontSize: 12.5, color: tk.danger))),
            ]),
          );
        case PayKind.card:
          return _Hint(icon: Icons.contactless_outlined, title: context.str('pos_pospaymentscreen_card_swipe'), text: method!.message.isNotEmpty ? method.message : context.str('pos_pospaymentscreen_card_reader'));
        case PayKind.upi:
          return _Hint(icon: Icons.qr_code_scanner_rounded, title: context.str('pos_pospaymentscreen_upi_scan_title'), text: method!.message.isNotEmpty ? method.message : context.str('pos_pospaymentscreen_upi_ask_scan'));
        case PayKind.other:
          return method!.message.isEmpty ? const SizedBox.shrink() : _Hint(icon: Icons.info_outline_rounded, title: method.name, text: method.message);
        case null:
          return const SizedBox.shrink();
      }
    }

    final brand = context.primary;
    final on = onColor(brand);

    return PosPage(
      title: context.str('pos_pospaymentscreen_title'),
      back: Routes.posCart,
      child: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.str('pos_pospaymentscreen_total_amount'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: on.withValues(alpha: 0.85))),
                  const SizedBox(height: 4),
                  FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(totalText, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: on))),
                ]),
              ),
              label('pos_pospaymentscreen_choose_method'),
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: Text(context.str('pos_pospaymentscreen_subtitle'), style: TextStyle(color: tk.text2))),
              if (quote.methods.isEmpty)
                PosErrorBox(context.str('pos_payment_no_methods'))
              else
                for (final x in quote.methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onTap: _busy ? null : () => setState(() => _methodId = x.id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: x.id == _methodId ? context.primary.withValues(alpha: 0.07) : tk.surface,
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: Border.all(color: x.id == _methodId ? context.primary : tk.border, width: x.id == _methodId ? 1.8 : 1),
                        ),
                        child: Row(children: [
                          SizedBox(width: 40, height: 40, child: x.icon.isEmpty ? Icon(iconOf(payKind(x.name)), color: context.primary) : CachedNetworkImage(imageUrl: x.icon, fit: BoxFit.contain, memCacheWidth: 120, errorWidget: (_, _, _) => Icon(iconOf(payKind(x.name)), color: context.primary))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), Text(subOf(payKind(x.name)), style: TextStyle(fontSize: 12.5, color: tk.text2))])),
                          Icon(x.id == _methodId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: x.id == _methodId ? context.primary : tk.border),
                        ]),
                      ),
                    ),
                  ),
              details(),
              if (_error != null) ...[const SizedBox(height: 14), PosErrorBox(_error!)],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canPay ? () => _pay(quote, method, total, totalText) : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(method == null ? context.str('pos_pospaymentscreen_choose_method') : fillAt(context.str('pos_pospaymentscreen_pay_via'), [totalText, method.name])),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(children: [
        Icon(icon, size: 36, color: context.primary),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), Text(text, style: TextStyle(color: tk.text2, height: 1.35))])),
      ]),
    );
  }
}