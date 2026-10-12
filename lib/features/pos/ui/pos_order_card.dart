import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_orders_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_orders_logic.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

Color toneColor(BuildContext context, OrderTone t) {
  final tk = context.tk;
  return switch (t) {
    OrderTone.primary => context.primary,
    OrderTone.cancelled => tk.danger,
    OrderTone.processing => tk.warning,
    OrderTone.ready => tk.success,
    OrderTone.completed => tk.info,
    OrderTone.expired => tk.text3,
  };
}

/// The badge of a status: its words from the status number, or the server's own words for one this app does not know.
class PosStatusBadge extends StatelessWidget {
  const PosStatusBadge({super.key, required this.status, this.serverText = ''});

  final int status;
  final String serverText;

  @override
  Widget build(BuildContext context) {
    final key = statusKey(status);
    final text = key != null ? stripBullet(context.str(key)) : (serverText.trim().isEmpty ? context.str('pos_posordersscreen_status_pending') : stripBullet(serverText));
    final c = toneColor(context, toneOf(status));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 6), Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)))]),
    );
  }
}

/// An order in a list. [action] (the queue's "Move to …" button) sits under it.
class PosOrderCard extends ConsumerWidget {
  const PosOrderCard({super.key, required this.order, this.action});

  final PosOrderRow order;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final currency = ref.watch(posCurrencyProvider);
    final name = order.customerName.trim().isEmpty ? context.str('pos_posordersscreen_walk_in') : order.customerName;
    final method = order.paymentMethod.isEmpty ? '' : order.paymentMethod[0].toUpperCase() + order.paymentMethod.substring(1);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('${Routes.posOrder}/${Uri.encodeComponent(order.orderId)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 20, backgroundColor: context.primary.withValues(alpha: 0.12), child: Text(name.trim()[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: context.primary))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                    Text('# ${order.orderNumber}${order.table.isEmpty ? '' : '  ·  ${order.table}'}', style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  ]),
                ),
                Text(money(currency, posAmountText(order.amount)), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PosChip(context.str(orderTypeKey(order.orderType)), context.primary),
                Text(context.str('pos_posheldcartsscreen_items_count', [order.quantity]), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                if (order.date.isNotEmpty) Text(posDateTime(context, order.date), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                if (method.isNotEmpty) Text(method, style: TextStyle(fontSize: 12.5, color: tk.text3)),
                PosStatusBadge(status: order.status, serverText: order.statusText),
              ]),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}