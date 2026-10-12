import 'package:cached_network_image/cached_network_image.dart';
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
import '../data/pos_checkout_repository.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_held.dart';
import '../logic/pos_order.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_customer_sheet.dart';
import 'pos_customize_sheet.dart';
import 'pos_promo_sheet.dart';
import 'pos_widgets.dart';

/// "Current Order": the items, the order type, the customer, the promo code and the bill the server calculates.
class PosCartScreen extends ConsumerWidget {
  const PosCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final items = ref.watch(posCartProvider);
    final cart = ref.read(posCartProvider.notifier);
    final choices = ref.watch(posOrderProvider);
    final quoteAsync = ref.watch(posQuoteProvider);
    final quote = quoteAsync.value; // the previous bill stays while a new one loads
    final staff = ref.watch(posAuthProvider).staff;
    final currency = ref.watch(posCurrencyProvider);
    final held = ref.watch(posHeldCartsProvider);
    final services = staff?.business.serviceTypes ?? const [];
    final serviceId = choices.serviceTypeId ?? services.firstOrNull?.id;
    String m(double v) => money(currency, posAmountText(v));

    Future<void> clearAll() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.delete_sweep_outlined, size: 36, color: ctx.tk.danger),
          title: Text(ctx.str('pos_poscartscreen_clear')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posheldcartsscreen_cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_poscartscreen_clear'))),
          ],
        ),
      );
      if (ok != true) return;
      final session = ref.read(posActiveSessionProvider).value;
      ref.read(posCheckoutRepositoryProvider).deleteCart(sessionId: session?.id ?? '', segmentId: staff?.business.segmentId ?? ''); // not waited for
      cart.clear();
      ref.read(posOrderProvider.notifier).reset();
    }

    void hold() {
      ref.read(posHeldCartsProvider.notifier).hold(items, customerName: choices.customer.walkIn ? '' : choices.customer.name);
      cart.clear();
      ref.read(posOrderProvider.notifier).reset();
      showAppSnack(context, context.str('pos_poscartscreen_hold_cart'));
    }

    Widget line(PosCartItem e) {
      final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.fastfood_outlined, color: tk.text3));
      final out = quote?.lineOutOfStock(e.variant.id) ?? false;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: e.product.image.isEmpty ? ph : CachedNetworkImage(imageUrl: e.product.image, fit: BoxFit.cover, memCacheWidth: 170, errorWidget: (_, _, _) => ph))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.product.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                if (e.product.variants.length > 1 || e.variant.label.isNotEmpty && e.product.variants.length > 1) Text(e.variant.label, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                for (final x in e.modifiers) Text('+ ${x.title}', style: TextStyle(fontSize: 12, color: tk.text3)),
                Text('${m(e.unitPrice)} ${context.str('pos_poscartscreen_each')}', style: TextStyle(fontSize: 12, color: tk.text3)),
                if (out) Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.danger)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m(e.lineTotal), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => cart.removeOne(e.key), icon: const Icon(Icons.remove_rounded, size: 18)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${e.quantity}', style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton.filled(visualDensity: VisualDensity.compact, onPressed: (roomFor(items, e.product, e.variant) == 0) ? null : () => cart.add(e.product, e.variant, modifiers: e.modifiers), icon: const Icon(Icons.add_rounded, size: 18)),
              ]),
            ]),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') showCustomizeSheet(context, e.product, editing: e);
                if (v == 'dup') cart.add(e.product, e.variant, modifiers: e.modifiers);
                if (v == 'del') cart.removeLine(e.key);
              },
              itemBuilder: (_) => [
                if (e.product.hasChoices) PopupMenuItem(value: 'edit', child: Text(context.str('pos_poscartscreen_action_edit'))),
                PopupMenuItem(value: 'dup', child: Text(context.str('pos_poscartscreen_action_duplicate'))),
                PopupMenuItem(value: 'del', child: Text(context.str('pos_poscartscreen_action_remove'), style: TextStyle(color: tk.danger))),
              ],
            ),
          ]),
        ),
      );
    }

    final Widget body;
    if (items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_bag_outlined, size: 56, color: tk.text3),
            const SizedBox(height: 12),
            Text(context.str('pos_posregisterscreen_select_products'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: () => context.go(Routes.posProducts), child: Text(context.str('pos_posdashboardscreen_nav_products'))),
          ]),
        ),
      );
    } else {
      final saved = cartSavings(items);
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (services.length > 1)
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final s in services)
                  Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(s.nameLocale.isNotEmpty ? s.nameLocale : s.name), selected: s.id == serviceId, onSelected: (_) => ref.read(posOrderProvider.notifier).setService(s.id))),
              ]),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () async {
                final c = await showCustomerSheet(context);
                if (c != null) ref.read(posOrderProvider.notifier).setCustomer(c);
              },
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.person_outline_rounded, color: context.primary)),
              title: Text(choices.customer.walkIn ? context.str('pos_posaddcustomerscreen_walk_in') : choices.customer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(choices.customer.walkIn ? context.str('pos_posaddcustomerscreen_walk_in_sub') : choices.customer.phone),
              trailing: Icon(Icons.chevron_right_rounded, color: tk.text3),
            ),
          ),
          const SizedBox(height: 12),
          for (final e in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: line(e)),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => showPromoSheet(context),
              leading: Icon(Icons.local_offer_outlined, color: context.primary),
              title: Text(choices.promoCode.isEmpty ? context.str('pos_poscartscreen_promo_sheet_title') : choices.promoCode, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: choices.promoCode.isEmpty ? null : Text(quote?.promoText.isNotEmpty == true ? quote!.promoText : context.str('pos_poscartscreen_promo_applied'), style: TextStyle(color: tk.success)),
              trailing: choices.promoCode.isEmpty ? Icon(Icons.chevron_right_rounded, color: tk.text3) : TextButton(onPressed: () => ref.read(posOrderProvider.notifier).setPromo(''), child: Text(context.str('pos_poscartscreen_promo_remove'))),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: quoteAsync.hasError && quote == null
                  ? Column(children: [PosErrorBox(errorText(quoteAsync.error!, ref.read(stringsProvider))), TextButton(onPressed: () => ref.invalidate(posQuoteProvider), child: Text(context.str('pos_posanalysisscreen_retry_button')))])
                  : quote == null
                  ? const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))))
                  : Column(children: [
                for (final b in quote.bill)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [Expanded(child: Text(b.name, style: TextStyle(color: b.bold ? tk.text1 : tk.text2, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w500))), Text(b.valueFormatted.isNotEmpty ? b.valueFormatted : money(currency, b.value), style: TextStyle(fontWeight: b.bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1))]),
                  ),
              ]),
            ),
          ),
          if (saved > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(children: [Icon(Icons.savings_outlined, size: 18, color: tk.success), const SizedBox(width: 8), Expanded(child: Text(context.str('pos_poscartscreen_you_save', [m(saved)]), style: TextStyle(color: tk.success, fontWeight: FontWeight.w700)))]),
            ),
          ],
          if (quote?.outOfStock == true) Padding(padding: const EdgeInsets.only(top: 10), child: PosErrorBox(context.str('pos_cart_out_of_stock_warning'))),
        ],
      );
    }

    final canPay = items.isNotEmpty && quote != null && !quote.outOfStock && quote.cartId.isNotEmpty && !quoteAsync.isLoading;
    final total = quote == null ? '' : (quote.totalText.isNotEmpty ? quote.totalText : money(currency, posAmountText(quote.cartAmount)));

    return PosPage(
      title: context.str('pos_poscartscreen_current_order'),
      back: Routes.posProducts,
      actions: [
        IconButton(
          tooltip: context.str('pos_poscartscreen_saved_carts'),
          onPressed: () => context.push(Routes.posHeldCarts),
          icon: Badge(isLabelVisible: held.isNotEmpty, label: Text('${held.length}'), child: const Icon(Icons.bookmarks_outlined)),
        ),
        if (items.isNotEmpty) TextButton(onPressed: clearAll, child: Text(context.str('pos_poscartscreen_clear'))),
      ],
      child: Column(children: [
        if (items.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(context.str('pos_poscartscreen_items_n', [cartCount(items)]), style: TextStyle(color: tk.text2)))),
        Expanded(child: body),
        if (items.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
            child: Row(children: [
              OutlinedButton(onPressed: hold, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(context.str('pos_poscartscreen_hold_cart'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: canPay ? () => context.push(Routes.posPayment) : null, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text('${context.str('pos_poscartscreen_proceed_payment')} $total'))),
            ]),
          ),
      ]),
    );
  }
}