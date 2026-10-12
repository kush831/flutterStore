import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_checkout_models.dart';
import '../data/pos_checkout_repository.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_checkout_logic.dart';
import '../logic/pos_order.dart';
import 'pos_widgets.dart';

Future<void> showPromoSheet(BuildContext context) {
  const body = _PromoSheet();
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720), child: body)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => body);
}

final _promosProvider = FutureProvider.autoDispose<List<PosPromo>>((ref) {
  ref.watch(posScopeProvider);
  return ref.watch(posCheckoutRepositoryProvider).promoCodes(ref.watch(posAuthProvider).staff?.business.segmentId ?? '');
});

class _PromoSheet extends ConsumerStatefulWidget {
  const _PromoSheet();

  @override
  ConsumerState<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends ConsumerState<_PromoSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(posActiveSessionProvider.future);
      // the server checks the code; a refusal comes back as its own message
      await ref.read(posCheckoutRepositoryProvider).applyPromo(sessionId: session?.id ?? '', code: code, segmentId: ref.read(posAuthProvider).staff?.business.segmentId ?? '');
      ref.read(posOrderProvider.notifier).setPromo(code.trim());
      _code.clear();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, ref.read(stringsProvider)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final applied = ref.watch(posOrderProvider.select((o) => o.promoCode));
    final async = ref.watch(_promosProvider);
    final promos = async.value ?? const <PosPromo>[];
    final currency = ref.watch(posCurrencyProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Row(children: [
              Expanded(child: Text(context.str('pos_poscartscreen_promo_sheet_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(context.str('pos_poscartscreen_promo_enter_label'), style: TextStyle(color: tk.text2))),
            Row(children: [
              Expanded(child: TextField(controller: _code, enabled: !_busy, textCapitalization: TextCapitalization.characters, onSubmitted: _apply, decoration: InputDecoration(hintText: context.str('pos_poscartscreen_promo_placeholder')))),
              const SizedBox(width: 10),
              FilledButton(onPressed: _busy ? null : () => _apply(_code.text), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(context.str('pos_poscartscreen_promo_apply'))),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: PosErrorBox(_error!)),
            if (promos.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(context.str('pos_poscartscreen_promo_available_label'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
              for (final p in promos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: applied == p.code ? tk.success : tk.border, width: applied == p.code ? 1.6 : 1)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(p.code, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                            const SizedBox(width: 8),
                            PosChip('${promoOffLabel(p, (v) => money(currency, v))} ${context.str('pos_poscartscreen_promo_off')}', tk.success),
                          ]),
                          if (p.description.isNotEmpty) Text(p.description, style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.35)),
                          if (p.minAmount > 0) Text('≥ ${money(currency, p.minAmount.toStringAsFixed(0))}', style: TextStyle(fontSize: 12, color: tk.text3)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      applied == p.code
                          ? TextButton(onPressed: () => ref.read(posOrderProvider.notifier).setPromo(''), child: Text(context.str('pos_poscartscreen_promo_remove')))
                          : OutlinedButton(onPressed: _busy ? null : () => _apply(p.code), child: Text(context.str('pos_poscartscreen_promo_apply'))),
                    ]),
                  ),
                ),
            ],
            if (applied.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.check_circle_rounded, color: tk.success, size: 18), const SizedBox(width: 6), Text('${context.str('pos_poscartscreen_promo_applied')}: $applied', style: TextStyle(color: tk.success, fontWeight: FontWeight.w700))])),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), child: Text(context.str('pos_poscartscreen_promo_done'))),
          ],
        ),
      ),
    );
  }
}