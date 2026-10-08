import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/membership_models.dart';
import '../data/membership_repository.dart';
import '../logic/membership_logic.dart';

/// Returns the server's message when the purchase went through, otherwise null.
Future<String?> showMembershipPay(BuildContext context, {required MembershipPlan plan, required List<PaymentOption> options, required String currency}) {
  final view = _PaySheet(plan: plan, options: options, currency: currency);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: view)));
  }
  return showModalBottomSheet<String>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => view);
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.plan, required this.options, required this.currency});

  final MembershipPlan plan;
  final List<PaymentOption> options;
  final String currency;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  late String _method = widget.options.isEmpty ? '' : widget.options.first.id; // the first one is pre-selected
  String? _error;
  bool _busy = false;

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(membershipRepositoryProvider).purchase(planId: widget.plan.id, methodId: _method, price: widget.plan.price);
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider)); // inside the sheet: a snackbar would hide behind it
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = widget.plan;
    final price = money(widget.currency, p.price);
    final parts = periodParts(p.period);
    final period = parts.key.isEmpty ? p.period : context.str(parts.key, parts.n == null ? const [] : [parts.n]);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.workspace_premium_rounded, color: context.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.heading, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                  Text('$price  ·  $period', style: TextStyle(color: tk.text2)),
                ]),
              ),
              IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            Text(context.str('membership_membershipscreen_choose_payment'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 8),
            if (widget.options.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(context.str('membership_membershipscreen_no_payment_options'), style: TextStyle(color: tk.text2)))
            else
              for (final o in widget.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap: _busy ? null : () => setState(() => _method = o.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: o.id == _method ? context.primary.withValues(alpha: 0.07) : tk.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: o.id == _method ? context.primary : tk.border, width: o.id == _method ? 1.6 : 1),
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: o.icon.isEmpty ? Icon(Icons.payments_outlined, color: tk.text3) : CachedNetworkImage(imageUrl: o.icon, fit: BoxFit.contain, memCacheWidth: 100, errorWidget: (_, _, _) => Icon(Icons.payments_outlined, color: tk.text3)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(o.name, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1))),
                        Icon(o.id == _method ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: o.id == _method ? context.primary : tk.border),
                      ]),
                    ),
                  ),
                ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_busy || _method.isEmpty) ? null : _pay,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: _busy
                  ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('financialsmodule_financialsmodule_submitting'))])
                  : Text(context.str('membership_membershipscreen_pay', [price])),
            ),
          ],
        ),
      ),
    );
  }
}