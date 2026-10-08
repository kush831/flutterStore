import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

/// Returns the server's message when the request was sent, otherwise null.
Future<String?> showCashoutRequest(BuildContext context, {required String balanceText}) {
  final editor = _CashoutRequest(balanceText: balanceText);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: editor)));
  }
  return showModalBottomSheet<String>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

class _CashoutRequest extends ConsumerStatefulWidget {
  const _CashoutRequest({required this.balanceText});

  final String balanceText;

  @override
  ConsumerState<_CashoutRequest> createState() => _CashoutRequestState();
}

class _CashoutRequestState extends ConsumerState<_CashoutRequest> {
  final _amount = TextEditingController();
  String? _errorKey;
  String? _serverError;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final key = validateCashoutAmount(_amount.text);
    setState(() {
      _errorKey = key;
      _serverError = null;
    });
    if (key != null) return;

    setState(() => _busy = true);
    try {
      final message = await ref.read(walletRepositoryProvider).requestCashout(_amount.text);
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = errorText(e, ref.read(stringsProvider)); // inside the sheet: a snackbar would hide behind it
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.account_balance_rounded, color: context.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.str('financialsmodule_financialsmodule_cashout_history_requestCashout'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                    Text(context.str('financialsmodule_financialsmodule_cashout_history_enterAmountToWithdraw'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                  ]),
                ),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [
                  Expanded(child: Text(context.str('financialsmodule_financialsmodule_header_available_balance_title'), style: TextStyle(color: tk.text2))),
                  Text(widget.balanceText, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str('financialsmodule_financialsmodule_enter_amount_title'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2))),
              TextField(
                controller: _amount,
                enabled: !_busy,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_errorKey != null) setState(() => _errorKey = null);
                },
                decoration: InputDecoration(hintText: context.str('financialsmodule_financialsmodule_enter_amount_title'), errorText: _errorKey == null ? null : context.str(_errorKey!)),
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_serverError!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                child: _busy
                    ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('financialsmodule_financialsmodule_submitting'))])
                    : Text(context.str('financialsmodule_financialsmodule_cashout_history_submitRequest')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}