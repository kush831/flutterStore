import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_catalog_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_catalog_providers.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_customize_sheet.dart';
import 'pos_variant_sheet.dart';

/// A product in the grid: photo, price, discount, and the way to add it (a "+", a stepper, or the Customize wizard).
class PosProductCard extends ConsumerWidget {
  const PosProductCard({super.key, required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final p = product;
    final currency = ref.watch(posCurrencyProvider);
    final isFood = ref.watch(posIsFoodProvider);
    final cart = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);
    final out = p.outOfStock;
    final v = p.firstVariant;
    final inCart = quantityOfProduct(cart, p.id);
    String m(double x) => money(currency, posAmountText(x));
    final fromPrice = p.fromPrice;
    final lineKey = cart.where((e) => e.product.id == p.id && e.variant.id == v.id && e.modifiers.isEmpty).firstOrNull?.key;
    final room = roomFor(cart, p, v);

    void choose() => isFood ? showCustomizeSheet(context, p) : showVariantSheet(context, p);

    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.restaurant_menu_rounded, color: tk.text3, size: 30));

    Widget control() {
      if (out) return const SizedBox.shrink();
      if (p.hasChoices) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: choose,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: inCart > 0 ? Text('$inCart  +') : const Icon(Icons.add_rounded),
          ),
        );
      }
      if (inCart == 0) {
        return SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: (room == 0) ? null : () => notifier.add(p, v), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), child: const Icon(Icons.add_rounded)));
      }
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton.filledTonal(onPressed: lineKey == null ? null : () => notifier.removeOne(lineKey), icon: const Icon(Icons.remove_rounded)),
        Text('$inCart', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        IconButton.filled(onPressed: (room == 0) ? null : () => notifier.add(p, v), icon: const Icon(Icons.add_rounded)),
      ]);
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : () => context.push('${Routes.posProduct}/${Uri.encodeComponent(p.id)}', extra: p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                p.image.isEmpty ? ph : CachedNetworkImage(imageUrl: p.image, fit: BoxFit.cover, memCacheWidth: 420, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph),
                if (p.percentOff > 0)
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: tk.danger, borderRadius: BorderRadius.circular(6)), child: Text(context.str('pos_posregisterscreen_discount_off', ['${p.percentOff}']), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800))),
                  ),
                if (isFood && (p.foodType == 1 || p.foodType == 2))
                  PositionedDirectional(top: 8, end: 8, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: p.foodType == 1 ? tk.success : tk.danger, width: 1.6), borderRadius: BorderRadius.circular(3)), child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: p.foodType == 1 ? tk.success : tk.danger, shape: BoxShape.circle))))),
                if (out) Container(color: Colors.black54, alignment: Alignment.center, child: Text(context.str('pos_posproductlistscreen_out_of_stock'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1, height: 1.2)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(m(fromPrice), style: TextStyle(fontWeight: FontWeight.w800, color: context.primary)),
                    if (p.variants.length == 1 && p.variants.first.hasDiscount) ...[const SizedBox(width: 6), Text(m(p.variants.first.base), style: TextStyle(fontSize: 12, color: tk.text3, decoration: TextDecoration.lineThrough))],
                  ]),
                  if (p.variants.length > 1) Text(context.str('pos_posgroceryproductcardscreen_variants_count', [p.variants.length]), style: TextStyle(fontSize: 11.5, color: tk.text3)),
                  const SizedBox(height: 6),
                  control(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}