import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../../splash/ui/brand_widgets.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_shift_logic.dart';

/// Set around the products while the cart panel is beside them: the "View cart" bar is not needed then.
class PosCartPaneVisible extends InheritedWidget {
  const PosCartPaneVisible({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PosCartPaneVisible>() != null;

  @override
  bool updateShouldNotify(PosCartPaneVisible old) => false;
}

/// "3 item(s) in cart · View cart ₹560": shown at the bottom of every selling screen once the cart has something in it.
class PosViewCartBar extends ConsumerWidget {
  const PosViewCartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PosCartPaneVisible.of(context)) return const SizedBox.shrink(); // the cart is already beside the products
    final count = ref.watch(posCartCountProvider);
    if (count == 0) return const SizedBox.shrink();
    final total = ref.watch(posCartTotalProvider);
    final currency = ref.watch(posCurrencyProvider);
    final brand = context.primary;
    final on = onColor(brand);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Material(
        color: brand,
        borderRadius: BorderRadius.circular(Radii.lg),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () => context.push(Routes.posCart),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(Icons.shopping_bag_outlined, color: on),
              const SizedBox(width: 10),
              Expanded(child: Text(context.str('pos_posregisterscreen_items_count', [count]), style: TextStyle(color: on, fontWeight: FontWeight.w700))),
              Text(money(currency, posAmountText(total)), style: TextStyle(color: on, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 10),
              Text(context.str('pos_posregisterscreen_view_cart'), style: TextStyle(color: on, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, color: on),
            ]),
          ),
        ),
      ),
    );
  }
}