import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../../home/ui/home_format.dart';
import '../data/pos_checkout_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_checkout_logic.dart';
import '../logic/pos_held.dart';
import '../logic/pos_order.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// Carts set aside with "Hold Cart": resume one, or throw it away. Jetpack's HeldCartsScreen.
/// Phone: cards in one column. Tablet and browser: the store app's page header, the search and the tabs on one row, and the carts in a grid.
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
    final wide = !context.screen.isCompact;
    final all = ref.watch(posHeldCartsProvider);
    final staffId = ref.watch(posAuthProvider.select((s) => s.staff?.staffId ?? ''));
    final currency = ref.watch(posCurrencyProvider);
    final now = DateTime.now();
    List<PosHeldCart> of(HeldTab t, {String q = ''}) => filterHeld(all, tab: t, staffId: staffId, query: q, now: now);
    final shown = of(_tab, q: _query);
    final title = context.str('pos_posheldcartsscreen_title');

    final searchField = TextField(onChanged: (v) => setState(() => _query = v), decoration: InputDecoration(hintText: context.str('pos_posheldcartsscreen_search'), prefixIcon: const Icon(Icons.search_rounded)));

    Widget tab(HeldTab t, String key) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(label: Text(context.str(key, [of(t).length])), selected: _tab == t, onSelected: (_) => setState(() => _tab = t)),
    );

    Widget tabs({double hPad = 16}) => ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: hPad), children: [tab(HeldTab.all, 'pos_posheldcartsscreen_tab_all'), tab(HeldTab.mine, 'pos_posheldcartsscreen_tab_mine'), tab(HeldTab.today, 'pos_posheldcartsscreen_tab_today')]);

    // one held cart, the same card on every width
    Widget cartCard(PosHeldCart h) {
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
                Expanded(child: Text(h.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
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
                Expanded(child: Text(context.str('pos_posheldcartsscreen_tap_resume'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: tk.text3))),
                TextButton(onPressed: () => ref.read(posHeldCartsProvider.notifier).remove(h.id), child: Text(context.str('pos_posheldcartsscreen_discard'), style: TextStyle(color: tk.danger))),
                FilledButton.tonal(onPressed: () => _resume(h), child: Text(context.str('pos_posheldcartsscreen_resume'))),
              ]),
            ]),
          ),
        ),
      );
    }

    final empty = FinanceMessage(icon: Icons.bookmarks_outlined, title: context.str(all.isEmpty ? 'pos_poscartscreen_saved_carts' : 'pos_posheldcartsscreen_no_match'));

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      return PosPage(
        title: title,
        back: Routes.posCart,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_posheldcartsscreen_count', [all.length]), style: TextStyle(color: tk.text2)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: searchField),
          SizedBox(height: 46, child: tabs()),
          Expanded(
            child: shown.isEmpty
                ? empty
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => cartCard(shown[i]),
            ),
          ),
        ]),
      );
    }

    // ══ tablet and browser: the carts in a grid ═══════════════════════════════
    return AdaptivePage(
      title: title,
      subtitle: context.str('pos_posheldcartsscreen_count', [all.length]),
      fallbackRoute: Routes.posCart,
      child: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 980 ? 3 : (box.maxWidth >= 620 ? 2 : 1);
        final rows = (shown.length / cols).ceil();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // the search and the tabs on one row when there is room, else the tabs under the search
          if (box.maxWidth >= 760)
            SizedBox(height: 50, child: Row(children: [SizedBox(width: 320, child: searchField), const SizedBox(width: 16), Expanded(child: tabs(hPad: 0))]))
          else ...[
            searchField,
            SizedBox(height: 50, child: tabs(hPad: 0)),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: shown.isEmpty
                ? empty
                : ListView.separated(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: rows,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, r) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(child: r * cols + c < shown.length ? cartCard(shown[r * cols + c]) : const SizedBox.shrink()),
                ],
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}