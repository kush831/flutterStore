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
import 'pos_view_cart_bar.dart'; // PosCartPaneVisible
import 'pos_widgets.dart';

/// Shows [child] (the products) with the live cart beside it when there is room (content 1000 px wide or more).
/// Narrower: just [child], and the "View cart" bar does the job.
/// Shows [child] (the products) with the live cart beside it when there is room (content 1000 px wide or more)
/// AND the cart has something in it. An empty cart shows no panel: the products take the whole width.
/// Narrower: just [child], and the "View cart" bar does the job.
class PosWithCartPane extends ConsumerWidget {
  const PosWithCartPane({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(posCartCountProvider) > 0;
    return LayoutBuilder(builder: (context, box) {
      if (!hasItems || box.maxWidth < 1000) return child;
      final panel = box.maxWidth >= 1300 ? 360.0 : 320.0;
      return Row(children: [
        Expanded(child: PosCartPaneVisible(child: child)),
        VerticalDivider(width: 1, color: context.tk.border),
        SizedBox(width: panel, child: const PosCartScreen(embedded: true)),
      ]);
    });
  }
}

/// "Current Order": the items, the order type, the customer, the promo code and the bill the server calculates.
/// A page of its own (phone, tablet, browser), or, with [embedded], the panel beside the products.
class PosCartScreen extends ConsumerWidget {
  const PosCartScreen({super.key, this.embedded = false});

  final bool embedded;

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

    PopupMenuButton<String> lineMenu(PosCartItem e, {double iconSize = 24, EdgeInsets padding = const EdgeInsets.all(8)}) => PopupMenuButton<String>(
      padding: padding,
      iconSize: iconSize,
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
    );

    Widget photo(PosCartItem e, double size) {
      final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.fastfood_outlined, color: tk.text3, size: size * 0.45));
      return ClipRRect(borderRadius: BorderRadius.circular(size > 50 ? 10 : 8), child: SizedBox(width: size, height: size, child: e.product.image.isEmpty ? ph : CachedNetworkImage(imageUrl: e.product.image, fit: BoxFit.cover, memCacheWidth: 170, errorWidget: (_, _, _) => ph)));
    }

    final saved = cartSavings(items);
    final canPay = items.isNotEmpty && quote != null && !quote.outOfStock && quote.cartId.isNotEmpty && !quoteAsync.isLoading;
    final total = quote == null ? '' : (quote.totalText.isNotEmpty ? quote.totalText : money(currency, posAmountText(quote.cartAmount)));
    final countText = items.isEmpty ? null : context.str('pos_poscartscreen_items_n', [cartCount(items)]);

    final savedCartsButton = IconButton(
      tooltip: context.str('pos_poscartscreen_saved_carts'),
      onPressed: () => context.push(Routes.posHeldCarts),
      icon: Badge(isLabelVisible: held.isNotEmpty, label: Text('${held.length}'), child: const Icon(Icons.bookmarks_outlined)),
    );
    final clearButton = items.isEmpty ? null : TextButton(onPressed: clearAll, child: Text(context.str('pos_poscartscreen_clear')));

    final notes = <Widget>[
      if (saved > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(children: [Icon(Icons.savings_outlined, size: 18, color: tk.success), const SizedBox(width: 8), Expanded(child: Text(context.str('pos_poscartscreen_you_save', [m(saved)]), style: TextStyle(color: tk.success, fontWeight: FontWeight.w700)))]),
          ),
        ),
      if (quote?.outOfStock == true) Padding(padding: const EdgeInsets.only(top: 10), child: PosErrorBox(context.str('pos_cart_out_of_stock_warning'))),
    ];

    final emptyState = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_bag_outlined, size: 56, color: tk.text3),
          const SizedBox(height: 12),
          Text(context.str('pos_posregisterscreen_select_products'), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
          if (!embedded) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: () => context.go(Routes.posProducts), child: Text(context.str('pos_posdashboardscreen_nav_products')))], // beside the products there is nothing to go to
        ]),
      ),
    );

    // ══ the panel beside the products (tablet, browser) ═══════════════════════
    if (embedded) {
      Widget qtyButton(IconData icon, VoidCallback? onTap, {bool filled = false}) {
        final style = IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap);
        return SizedBox(width: 28, height: 28, child: filled ? IconButton.filled(style: style, iconSize: 16, onPressed: onTap, icon: Icon(icon)) : IconButton.filledTonal(style: style, iconSize: 16, onPressed: onTap, icon: Icon(icon)));
      }

      Widget itemTile(PosCartItem e) {
        final out = quote?.lineOutOfStock(e.variant.id) ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            photo(e, 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tk.text1)))),
                  SizedBox(width: 28, height: 24, child: lineMenu(e, iconSize: 18, padding: EdgeInsets.zero)),
                ]),
                if (e.product.variants.length > 1 && e.variant.label.isNotEmpty) Text(e.variant.label, style: TextStyle(fontSize: 11.5, color: tk.text2)),
                for (final x in e.modifiers) Text('+ ${x.title}', style: TextStyle(fontSize: 11.5, color: tk.text3)),
                if (out) Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tk.danger)),
                const SizedBox(height: 6),
                Row(children: [
                  qtyButton(Icons.remove_rounded, () => cart.removeOne(e.key)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${e.quantity}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  qtyButton(Icons.add_rounded, (roomFor(items, e.product, e.variant) == 0) ? null : () => cart.add(e.product, e.variant, modifiers: e.modifiers), filled: true),
                  const Spacer(),
                  Text(m(e.lineTotal), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                ]),
              ]),
            ),
          ]),
        );
      }

      // order type (the chips wrap onto a second line instead of being cut) and the customer, as one compact row
      final top = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (services.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in services)
                  ChoiceChip(visualDensity: VisualDensity.compact, label: Text(s.nameLocale.isNotEmpty ? s.nameLocale : s.name, style: const TextStyle(fontSize: 12.5)), selected: s.id == serviceId, onSelected: (_) => ref.read(posOrderProvider.notifier).setService(s.id)),
              ]),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () async {
              final c = await showCustomerSheet(context);
              if (c != null) ref.read(posOrderProvider.notifier).setCustomer(c);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
              child: Row(children: [
                Icon(Icons.person_outline_rounded, size: 20, color: context.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(choices.customer.walkIn ? context.str('pos_posaddcustomerscreen_walk_in') : choices.customer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: tk.text1)),
                    Text(choices.customer.walkIn ? context.str('pos_posaddcustomerscreen_walk_in_sub') : choices.customer.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: tk.text3)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: tk.text3),
              ]),
            ),
          ),
        ]),
      );

      // always in view: the promo, the bill and the buttons
      final billRows = quoteAsync.hasError && quote == null
          ? Column(children: [PosErrorBox(errorText(quoteAsync.error!, ref.read(stringsProvider))), TextButton(onPressed: () => ref.invalidate(posQuoteProvider), child: Text(context.str('pos_posanalysisscreen_retry_button')))])
          : quote == null
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))))
          : Column(children: [
        for (final b in quote.bill)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [Expanded(child: Text(b.name, style: TextStyle(fontSize: b.bold ? 14.5 : 13, color: b.bold ? tk.text1 : tk.text2, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w500))), Text(b.valueFormatted.isNotEmpty ? b.valueFormatted : money(currency, b.value), style: TextStyle(fontSize: b.bold ? 14.5 : 13, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1))]),
          ),
      ]);

      final bottom = Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () => showPromoSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.local_offer_outlined, size: 18, color: context.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(choices.promoCode.isEmpty ? context.str('pos_poscartscreen_promo_sheet_title') : '${choices.promoCode}${quote?.promoText.isNotEmpty == true ? '  ·  ${quote!.promoText}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: choices.promoCode.isEmpty ? tk.text1 : tk.success))),
                choices.promoCode.isEmpty
                    ? Icon(Icons.chevron_right_rounded, size: 20, color: tk.text3)
                    : TextButton(style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: () => ref.read(posOrderProvider.notifier).setPromo(''), child: Text(context.str('pos_poscartscreen_promo_remove'))),
              ]),
            ),
          ),
          Divider(height: 8, color: tk.border),
          billRows,
          ...notes,
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton(onPressed: hold, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 14)), child: Text(context.str('pos_poscartscreen_hold_cart'))),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: canPay ? () => context.push(Routes.posPayment) : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text('${context.str('pos_poscartscreen_proceed_payment')} $total', maxLines: 1)),
              ),
            ),
          ]),
        ]),
      );

      return Material(
        color: tk.canvas,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
            color: tk.surface,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.str('pos_poscartscreen_current_order'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
                  if (countText != null) Text(countText, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                ]),
              ),
              savedCartsButton,
              ?clearButton,
            ]),
          ),
          Divider(height: 1, color: tk.border),
          Expanded(
            child: items.isEmpty
                ? emptyState
                : Column(children: [
              top,
              Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), children: [for (final e in items) itemTile(e)])),
              bottom,
            ]),
          ),
        ]),
      );
    }

    // ══ a page of its own (phone, tablet, browser) ════════════════════════════
    Widget line(PosCartItem e) {
      final out = quote?.lineOutOfStock(e.variant.id) ?? false;
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.product.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
        if (e.product.variants.length > 1 && e.variant.label.isNotEmpty) Text(e.variant.label, style: TextStyle(fontSize: 12.5, color: tk.text2)),
        for (final x in e.modifiers) Text('+ ${x.title}', style: TextStyle(fontSize: 12, color: tk.text3)),
        Text('${m(e.unitPrice)} ${context.str('pos_poscartscreen_each')}', style: TextStyle(fontSize: 12, color: tk.text3)),
        if (out) Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.danger)),
      ]);
      final stepper = Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => cart.removeOne(e.key), icon: const Icon(Icons.remove_rounded, size: 18)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${e.quantity}', style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton.filled(visualDensity: VisualDensity.compact, onPressed: (roomFor(items, e.product, e.variant) == 0) ? null : () => cart.add(e.product, e.variant, modifiers: e.modifiers), icon: const Icon(Icons.add_rounded, size: 18)),
      ]);
      final price = Text(m(e.lineTotal), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1));
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, box) {
            if (box.maxWidth < 380) {
              // a phone: the stepper and the price get a row of their own
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [photo(e, 56), const SizedBox(width: 12), Expanded(child: info), lineMenu(e)]),
                const SizedBox(height: 8),
                Row(children: [stepper, const Spacer(), price]),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              photo(e, 56),
              const SizedBox(width: 12),
              Expanded(child: info),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [price, const SizedBox(height: 6), stepper]),
              lineMenu(e),
            ]);
          }),
        ),
      );
    }

    final serviceChips = services.length > 1
        ? SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final s in services)
          Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(s.nameLocale.isNotEmpty ? s.nameLocale : s.name), selected: s.id == serviceId, onSelected: (_) => ref.read(posOrderProvider.notifier).setService(s.id))),
      ]),
    )
        : null;

    final customerCard = Card(
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
    );

    final promoCard = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => showPromoSheet(context),
        leading: Icon(Icons.local_offer_outlined, color: context.primary),
        title: Text(choices.promoCode.isEmpty ? context.str('pos_poscartscreen_promo_sheet_title') : choices.promoCode, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: choices.promoCode.isEmpty ? null : Text(quote?.promoText.isNotEmpty == true ? quote!.promoText : context.str('pos_poscartscreen_promo_applied'), style: TextStyle(color: tk.success)),
        trailing: choices.promoCode.isEmpty ? Icon(Icons.chevron_right_rounded, color: tk.text3) : TextButton(onPressed: () => ref.read(posOrderProvider.notifier).setPromo(''), child: Text(context.str('pos_poscartscreen_promo_remove'))),
      ),
    );

    final billCard = Card(
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
    );

    final payBar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
      child: Row(children: [
        OutlinedButton(onPressed: hold, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(context.str('pos_poscartscreen_hold_cart'))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(onPressed: canPay ? () => context.push(Routes.posPayment) : null, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: FittedBox(fit: BoxFit.scaleDown, child: Text('${context.str('pos_poscartscreen_proceed_payment')} $total', maxLines: 1)))),
      ]),
    );

    final Widget body;
    if (items.isEmpty) {
      body = emptyState;
    } else {
      body = LayoutBuilder(builder: (context, box) {
        final itemRows = [for (final e in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: line(e))];
        if (box.maxWidth >= 720) {
          // a tablet or a browser: the items on the left, the order summary and the pay button on the right
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(0, 4, 16, 16), children: itemRows)),
            VerticalDivider(width: 1, color: tk.border),
            SizedBox(
              width: 360,
              child: Column(children: [
                Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 0, 16), children: [?serviceChips, if (serviceChips != null) const SizedBox(height: 8), customerCard, const SizedBox(height: 12), promoCard, const SizedBox(height: 12), billCard, ...notes])),
                payBar,
              ]),
            ),
          ]);
        }
        return Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [?serviceChips, customerCard, const SizedBox(height: 12), ...itemRows, promoCard, const SizedBox(height: 12), billCard, ...notes])),
          payBar,
        ]);
      });
    }

    return PosPage(
      title: context.str('pos_poscartscreen_current_order'),
      subtitle: countText,
      back: Routes.posProducts,
      actions: [savedCartsButton, ?clearButton],
      child: Column(children: [
        if (countText != null) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(countText, style: TextStyle(color: tk.text2)))),
        Expanded(child: body),
      ]),
    );
  }
}