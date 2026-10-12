import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_sale.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_receipt_actions.dart';

/// "Payment Successful!": the order number, how it was paid, the change, and what to do next. Jetpack's POSOrderSuccessScreen.
class PosOrderSuccessScreen extends ConsumerStatefulWidget {
  const PosOrderSuccessScreen({super.key});

  @override
  ConsumerState<PosOrderSuccessScreen> createState() => _PosOrderSuccessScreenState();
}

class _PosOrderSuccessScreenState extends ConsumerState<PosOrderSuccessScreen> {
  bool _busy = false;

  Future<void> _do(Future<Object?> Function(PosReceiptActions a) action) async {
    final sale = ref.read(posLastSaleProvider);
    if (sale == null || _busy) return;
    setState(() => _busy = true);
    try {
      final receipt = await ref.read(posReceiptProvider(sale.orderId).future);
      if (!mounted) return;
      final staff = ref.read(posAuthProvider).staff;
      final a = PosReceiptActions(context, receipt: receipt, store: staff?.business.name ?? '', phone: staff?.business.phone ?? '', currency: ref.read(posCurrencyProvider), sale: sale);
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
    final sale = ref.watch(posLastSaleProvider);
    final currency = ref.watch(posCurrencyProvider);
    if (sale == null) return const SizedBox.shrink();

    Widget square(IconData icon, String key, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
          child: Column(children: [Icon(icon, color: context.primary), const SizedBox(height: 6), Text(context.str(key), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))]),
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.posProducts);
      },
      child: Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                children: [
                  Center(child: Container(width: 84, height: 84, decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 50, color: tk.success))),
                  const SizedBox(height: 18),
                  Text(context.str('pos_pospaymentscreen_success_title'), textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1)),
                  const SizedBox(height: 6),
                  if (sale.orderNumber.isNotEmpty) Text('${context.str('pos_posreceiptscreen_label_order_number')} ${sale.orderNumber}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text2)),
                  if (sale.totalText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(sale.totalText, textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: tk.text1))),
                  if (sale.methodName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.str('pos_pospaymentscreen_success_paid_via', [sale.methodName]), textAlign: TextAlign.center, style: TextStyle(color: tk.text2))),
                  if (sale.changeDue != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.str('pos_pospaymentscreen_success_change', [money(currency, posAmountText(sale.changeDue!))]), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.success))),
                  const SizedBox(height: 26),
                  FilledButton(onPressed: () => context.push('${Routes.posReceipt}/${Uri.encodeComponent(sale.orderId)}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 54)), child: Text(context.str('pos_pospaymentscreen_success_view_receipt'))),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _busy ? null : () => _do((a) => a.print()), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), icon: const Icon(Icons.print_outlined), label: Text(context.str('pos_pospaymentscreen_success_print'))),
                  const SizedBox(height: 18),
                  Text(context.str('pos_pospaymentscreen_success_send_receipt'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)),
                  const SizedBox(height: 8),
                  Row(children: [
                    square(Icons.chat_bubble_outline_rounded, 'pos_pospaymentscreen_success_sms', () => _do((a) => a.sms())),
                    const SizedBox(width: 10),
                    square(Icons.mail_outline_rounded, 'pos_pospaymentscreen_success_email', () => _do((a) => a.email())),
                  ]),
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator(minHeight: 3)),
                  const SizedBox(height: 26),
                  TextButton(onPressed: () => context.go(Routes.posProducts), child: Text(context.str('pos_pospaymentscreen_success_new_sale'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}