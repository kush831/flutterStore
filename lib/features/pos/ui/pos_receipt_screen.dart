import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_sale_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_sale.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_receipt_actions.dart';
import 'pos_widgets.dart';

/// The receipt of a placed order, with the ways to hand it to the customer. Jetpack's POSReceiptScreen.
class PosReceiptScreen extends ConsumerStatefulWidget {
  const PosReceiptScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PosReceiptScreen> createState() => _PosReceiptScreenState();
}

class _PosReceiptScreenState extends ConsumerState<PosReceiptScreen> {
  bool _busy = false;

  Future<void> _do(PosReceiptActions a, Future<Object?> Function(PosReceiptActions a) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await action(a);
      if (r == false && mounted) showAppSnack(context, context.str('common_allscreen_something_went_wrong'), error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(posReceiptProvider(widget.orderId));
    final r = async.value;
    final staff = ref.watch(posAuthProvider).staff;
    final currency = ref.watch(posCurrencyProvider);
    final lastSale = ref.watch(posLastSaleProvider);
    final sale = (lastSale != null && lastSale.orderId == widget.orderId) ? lastSale : null; // cash tendered and change are only known right after the payment
    String cur(String v) => money(currency, v);
    String amt(double v) => money(currency, posAmountText(v));

    final Widget body;
    if (r == null) {
      body = async.hasError
          ? Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 12),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(posReceiptProvider(widget.orderId)), child: Text(context.str('pos_posanalysisscreen_retry_button'))),
        ]),
      )
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: SkeletonBox(height: 420, radius: 16)));
    } else {
      final actions = PosReceiptActions(context, receipt: r, store: staff?.business.name ?? '', phone: staff?.business.phone ?? '', currency: currency, sale: sale);

      Widget kv(String key, String value, {bool bold = false}) => value.isEmpty
          ? const SizedBox.shrink()
          : Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), const SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1)))]),
      );

      Widget action(IconData icon, String key, Future<Object?> Function(PosReceiptActions a) run) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: _busy ? null : () => _do(actions, run),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [Icon(icon, color: context.primary), const SizedBox(height: 4), Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tk.text2))])),
        ),
      );

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(staff?.business.name ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
              if ((staff?.business.phone ?? '').isNotEmpty) Text(staff!.business.phone, textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
              const SizedBox(height: 6),
              Text(context.str('pos_posreceiptscreen_title'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text3)),
              Divider(height: 24, color: tk.border),
              kv('pos_posreceiptscreen_label_receipt_no', r.orderId),
              kv('pos_posreceiptscreen_label_order_number', r.orderNumber),
              kv('pos_posreceiptscreen_date', r.date.isEmpty ? '' : posDateTime(context, r.date)),
              kv('pos_posreceiptscreen_label_cashier', r.cashier),
              kv('pos_posreceiptscreen_label_type', r.serviceType.isNotEmpty ? r.serviceType : r.orderType),
              kv('pos_receipt_customer', r.customerName),
              Divider(height: 24, color: tk.border),
              Row(children: [
                Expanded(child: Text(context.str('pos_posreceiptscreen_col_item'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3))),
                SizedBox(width: 40, child: Text(context.str('pos_posreceiptscreen_col_qty'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3))),
                SizedBox(width: 84, child: Text(context.str('pos_posreceiptscreen_col_amount'), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3))),
              ]),
              const SizedBox(height: 6),
              for (final i in r.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(i.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
                      SizedBox(width: 40, child: Text('${i.quantity}', textAlign: TextAlign.center, style: TextStyle(color: tk.text1))),
                      SizedBox(width: 84, child: Text(cur(i.total), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
                    ]),
                    if (i.variant.isNotEmpty) Text(i.variant, style: TextStyle(fontSize: 12, color: tk.text3)),
                    for (final o in i.options) Text('+ ${o.name}', style: TextStyle(fontSize: 12, color: tk.text3)),
                  ]),
                ),
              Divider(height: 24, color: tk.border),
              for (final b in r.bill)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [Expanded(child: Text(b.name, style: TextStyle(color: b.bold ? tk.text1 : tk.text2, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w500))), Text(b.valueFormatted.isNotEmpty ? b.valueFormatted : cur(b.value), style: TextStyle(fontWeight: b.bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1))]),
                ),
              Divider(height: 24, color: tk.border),
              kv('pos_posreceiptscreen_label_paid_via', r.paymentMethod),
              if (sale?.cashReceived != null) kv('pos_posreceiptscreen_label_cash_tendered', amt(sale!.cashReceived!)),
              if (sale?.changeDue != null) kv('pos_posreceiptscreen_label_change', amt(sale!.changeDue!)),
              const SizedBox(height: 14),
              Text(context.str('pos_posreceiptscreen_thank_order'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 2),
              Text(context.str('pos_posreceiptscreen_no_returns_note'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: tk.text3)),
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(children: [
                action(Icons.ios_share_rounded, 'pos_posreceiptscreen_action_share', (a) => a.share()),
                action(Icons.print_outlined, 'pos_posreceiptscreen_action_print', (a) => a.print()),
                action(Icons.chat_outlined, 'pos_posreceiptscreen_whatsapp', (a) => a.whatsapp()),
                action(Icons.sms_outlined, 'pos_posreceiptscreen_action_sms', (a) => a.sms()),
                action(Icons.mail_outline_rounded, 'pos_posreceiptscreen_action_email', (a) => a.email()),
              ]),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 3)),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => context.go(Routes.posProducts), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(context.str('pos_posreceiptscreen_new_order'))),
        ],
      );
    }

    return PosPage(title: context.str('pos_posreceiptscreen_title'), back: Routes.posProducts, child: body);
  }
}