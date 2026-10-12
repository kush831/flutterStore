import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';

enum LoginType { pos, store }

Future<LoginType?> showLoginTypeSheet(BuildContext context) {
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<LoginType>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const _LoginTypeBody())));
  }
  return showModalBottomSheet<LoginType>(context: context, isScrollControlled: true, builder: (_) => const _LoginTypeBody());
}

class _LoginTypeBody extends StatelessWidget {
  const _LoginTypeBody();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget card(IconData icon, String titleKey, String subtitleKey, LoginType type, {String? badge}) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => Navigator.pop(context, type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: context.primary)),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: context.primary, borderRadius: BorderRadius.circular(50)),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 14),
              Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 4),
              Text(context.str(subtitleKey), style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.35)),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.str('pos_logintype_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: tk.text1)),
            const SizedBox(height: 6),
            Text(context.str('pos_logintype_subtitle'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                card(Icons.point_of_sale_rounded, 'pos_logintype_pos_title', 'pos_logintype_pos_subtitle', LoginType.pos, badge: 'POS'),
                const SizedBox(width: 12),
                card(Icons.storefront_outlined, 'pos_logintype_store_title', 'pos_logintype_store_subtitle', LoginType.store),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}