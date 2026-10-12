import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_catalog_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_shift_logic.dart';

Future<void> showVariantSheet(BuildContext context, PosProduct product) {
  final body = _VariantSheet(product: product);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640), child: body)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => body);
}

/// A product with several variants (sizes, weights): each has its own price and its own quantity.
class _VariantSheet extends ConsumerWidget {
  const _VariantSheet({required this.product});

  final PosProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final cart = ref.watch(posCartProvider);
    final currency = ref.watch(posCurrencyProvider);
    final notifier = ref.read(posCartProvider.notifier);
    String m(double v) => money(currency, posAmountText(v));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(context.str('pos_posgroceryvariantscreen_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            Text(product.name, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in product.variants)
                        () {
                      final qty = quantityOfVariant(cart, product.id, v.id);
                      final room = roomFor(cart, product, v);
                      final soldOut = product.manageInventory && v.stock != null && v.stock! <= 0;
                      final key = cart.where((e) => e.product.id == product.id && e.variant.id == v.id && e.modifiers.isEmpty).firstOrNull?.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: qty > 0 ? context.primary : tk.border)),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(v.label, style: TextStyle(fontWeight: FontWeight.w800, color: soldOut ? tk.text3 : tk.text1)),
                                Row(children: [
                                  Text(m(v.unit), style: TextStyle(fontWeight: FontWeight.w700, color: context.primary)),
                                  if (v.hasDiscount) ...[const SizedBox(width: 6), Text(m(v.base), style: TextStyle(fontSize: 12, color: tk.text3, decoration: TextDecoration.lineThrough))],
                                ]),
                                if (soldOut) Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(fontSize: 12, color: tk.danger))
                                else if (product.manageInventory && v.stock != null) Text(context.str('pos_posproductdetailscreen_stock', [v.stock!]), style: TextStyle(fontSize: 12, color: tk.text3)),
                              ]),
                            ),
                            if (qty == 0)
                              FilledButton.tonal(onPressed: (soldOut || room == 0) ? null : () => notifier.add(product, v), style: FilledButton.styleFrom(minimumSize: const Size(44, 40)), child: const Icon(Icons.add_rounded))
                            else
                              Row(children: [
                                IconButton.filledTonal(onPressed: key == null ? null : () => notifier.removeOne(key), icon: const Icon(Icons.remove_rounded)),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                                IconButton.filled(onPressed: (room == 0) ? null : () => notifier.add(product, v), icon: const Icon(Icons.add_rounded)),
                              ]),
                          ]),
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}