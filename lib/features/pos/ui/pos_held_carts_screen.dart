import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../../home/ui/home_format.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_checkout_logic.dart';
import '../logic/pos_held.dart';
import '../logic/pos_order.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// Carts set aside with "Hold Cart": resume one, or throw it away. Jetpack's HeldCartsScreen.
class PosHeldCartsScreen extends ConsumerStatefulWidget {
  const PosHeldCartsScreen({super.key});

  @override
  ConsumerState<PosHeldCartsScreen> createState() => _PosHeldCartsScreenState();
}

class _PosHeldCartsScreenState extends ConsumerState<PosHeldCartsScreen> {
  HeldTab _tab = HeldTab.all;
  String _query = '';

  void _load(PosHeldCart h) {
    final cart = ref.read(posCartProvider.notifier);
    cart.clear();
    for (final i in h.items) {
      cart.add(i.product, i.variant, modifiers: i.modifiers, qty: i.quantity);
    }
    ref.read(posHeldCartsProvider.notifier).remove(h.id);
    context.go(Routes.posCart);
  }

  Future<void> _resume(PosHeldCart h) async {
    final active = ref.read(posCartProvider);
    if (active.isEmpty) return _load(h);
    // an open cart in the way: hold it, drop it, or cancel (Jetpack's "Resume Held Cart?")
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.str('pos_posheldcartsscreen_resume_conflict_title')),
        content: Text(ctx.str('pos_posheldcartsscreen_resume_conflict_message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.str('pos_posheldcartsscreen_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'drop'), child: Text(ctx.str('pos_posheldcartsscreen_discard_current_and_resume'), style: TextStyle(color: ctx.tk.danger))),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'hold'), child: Text(ctx.str('pos_posheldcartsscreen_hold_current_and_resume'))),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'hold') ref.read(posHeldCartsProvider.notifier).hold(active, customerName: ref.read(posOrderProvider).customer.walkIn ? '' : ref.read(posOrderProvider).customer.name);
    _load(h);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final all = ref.watch(posHeldCartsProvider);
    final staffId = ref.watch(posAuthProvider.select((s) => s.staff?.staffId ?? ''));
    final currency = ref.watch(posCurrencyProvider);
    final now = DateTime.now();
    List<PosHeldCart> of(HeldTab t, {String q = ''}) => filterHeld(all, tab: t, staffId: staffId, query: q, now: now);
    final shown = of(_tab, q: _query);

    Widget tab(HeldTab t, String key) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(label: Text(context.str(key, [of(t).length])), selected: _tab == t, onSelected: (_) => setState(() => _tab = t)),
    );

    return PosPage(
      title: context.str('pos_posheldcartsscreen_title'),
      back: Routes.posCart,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_posheldcartsscreen_count', [all.length]), style: TextStyle(color: tk.text2)))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: TextField(onChanged: (v) => setState(() => _query = v), decoration: InputDecoration(hintText: context.str('pos_posheldcartsscreen_search'), prefixIcon: const Icon(Icons.search_rounded)))),
        SizedBox(height: 46, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [tab(HeldTab.all, 'pos_posheldcartsscreen_tab_all'), tab(HeldTab.mine, 'pos_posheldcartsscreen_tab_mine'), tab(HeldTab.today, 'pos_posheldcartsscreen_tab_today')])),
        Expanded(
          child: shown.isEmpty
              ? FinanceMessage(icon: Icons.bookmarks_outlined, title: context.str(all.isEmpty ? 'pos_poscartscreen_saved_carts' : 'pos_posheldcartsscreen_no_match'))
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final h = shown[i];
              final age = heldAge(h.createdAt, now);
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _resume(h),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        PosChip(context.str('pos_posheldcartsscreen_badge'), tk.warning),
                        const SizedBox(width: 8),
                        Expanded(child: Text(h.id, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
                        Text(context.str(age.key, age.n == null ? const [] : [age.n]), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                      ]),
                      const SizedBox(height: 6),
                      Text(h.customerName.isEmpty ? context.str('pos_posaddcustomerscreen_walk_in') : h.customerName, style: TextStyle(color: tk.text2)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(context.str('pos_posheldcartsscreen_items_count', [h.count]), style: TextStyle(color: tk.text2)),
                        const Spacer(),
                        Text(money(currency, posAmountText(h.total)), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text(context.str('pos_posheldcartsscreen_tap_resume'), style: TextStyle(fontSize: 12, color: tk.text3))),
                        TextButton(onPressed: () => ref.read(posHeldCartsProvider.notifier).remove(h.id), child: Text(context.str('pos_posheldcartsscreen_discard'), style: TextStyle(color: tk.danger))),
                        FilledButton.tonal(onPressed: () => _resume(h), child: Text(context.str('pos_posheldcartsscreen_resume'))),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}