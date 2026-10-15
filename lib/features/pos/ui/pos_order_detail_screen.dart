import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_catalog_models.dart';
import '../data/pos_orders_models.dart';
import '../data/pos_orders_repository.dart';
import '../data/pos_permission.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_orders_logic.dart';
import '../logic/pos_orders_providers.dart';
import '../logic/pos_sale.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_order_card.dart';
import 'pos_widgets.dart';

/// One order: its items, the payment summary, the timeline, and what can be done with it. Jetpack's POSOrderDetailScreen.
/// Phone: one column, the buttons at the bottom. Tablet and browser: the store app's page header with the buttons on the right, and two columns.
class PosOrderDetailScreen extends ConsumerStatefulWidget {
  const PosOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PosOrderDetailScreen> createState() => _PosOrderDetailScreenState();
}

class _PosOrderDetailScreenState extends ConsumerState<PosOrderDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance(PosOrdersRepositoryRef repo, int next) => _run(() async {
    await repo.updateStatus(widget.orderId, next);
    ref.invalidate(posOrdersProvider);
    ref.invalidate(posReceiptProvider(widget.orderId));
  });

  Future<void> _cancel(PosOrdersRepositoryRef repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.cancel_outlined, size: 38, color: ctx.tk.danger),
        title: Text(ctx.str('pos_posorderdetailscreen_cancel_alert_title')),
        content: Text(ctx.str('pos_posorderdetailscreen_cancel_alert_message'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posorderdetailscreen_no'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posorderdetailscreen_cancel_confirm_button'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await repo.cancel(widget.orderId);
      ref.invalidate(posOrdersProvider);
      if (mounted) context.go('${Routes.posOrders}?tab=cancelled'); // Jetpack opens the Cancelled tab
    });
  }

  void _reorder(PosOrderLines lines) {
    final cart = ref.read(posCartProvider.notifier);
    for (final l in lines) {
      cart.add(l.product, l.variant, modifiers: l.modifiers, qty: l.qty);
    }
    context.go(Routes.posCart);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final async = ref.watch(posReceiptProvider(widget.orderId));
    final r = async.value;
    final auth = ref.watch(posAuthProvider);
    final currency = ref.watch(posCurrencyProvider);
    final repo = ref.read(posOrdersRepositoryProvider);
    String cur(String v) => money(currency, v);

    Future<void> refresh() async => ref.invalidate(posReceiptProvider(widget.orderId));

    // ── before the order is here ─────────────────────────────────────────────
    if (r == null) {
      final Widget state = async.hasError
          ? Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 12),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: refresh, child: Text(context.str('pos_posordersscreen_try_again'))),
        ]),
      )
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 110, radius: 16), SizedBox(height: 12), SkeletonBox(height: 200, radius: 16), SizedBox(height: 12), SkeletonBox(height: 140, radius: 16)])));
      return PosPage(title: context.str('pos_posordersscreen_title'), back: Routes.posOrders, child: state);
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    Widget card(String? titleKey, List<Widget> rows) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (titleKey != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.str(titleKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tk.text3))),
          ...rows,
        ]),
      ),
    );
    Widget kv(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: tk.text2))), Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1)))]));

    final next = nextStatus(r.status);
    final nextKey = nextActionKey(r.status);
    final perm = nextPermission(r.status);
    final canNext = next != null && nextKey != null && perm != null && auth.can(perm);
    final cancellable = canCancel(r.status) && auth.can(PosPerm.ordersCancel);
    final done = r.status == kOrderCompleted;
    final name = r.customerName.trim().isEmpty ? context.str('pos_posorderdetailscreen_guest') : r.customerName;
    final lines = reorderLines(r);

    final customerCard = card(null, [
      Row(children: [
        CircleAvatar(backgroundColor: context.primary.withValues(alpha: 0.12), child: Text(name.trim()[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: context.primary))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), if (r.customerPhone.isNotEmpty) Text(r.customerPhone, style: TextStyle(color: tk.text2))])),
        PosChip(context.str(orderTypeKey(r.orderType)), context.primary),
      ]),
      if (r.table.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(r.table, style: TextStyle(color: tk.text2))),
    ]);

    final itemsCard = card('pos_posorderdetailscreen_items', [
      for (final i in r.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i.quantity} ×  ', style: TextStyle(fontWeight: FontWeight.w800, color: context.primary)),
              Expanded(child: Text(i.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
              Text(cur(i.total), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
            ]),
            if (i.variant.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 26), child: Text(i.variant, style: TextStyle(fontSize: 12.5, color: tk.text2))),
            for (final o in i.options) Padding(padding: const EdgeInsets.only(left: 26), child: Text('+ ${o.name}', style: TextStyle(fontSize: 12.5, color: tk.text3))),
          ]),
        ),
    ]);

    final paymentCard = card('pos_posorderdetailscreen_payment_summary', [
      for (final b in r.bill)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(b.name, style: TextStyle(color: b.bold ? tk.text1 : tk.text2, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w500))), Text(b.valueFormatted.isNotEmpty ? b.valueFormatted : cur(b.value), style: TextStyle(fontWeight: b.bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1))]),
        ),
      if (r.paymentMethod.isNotEmpty) ...[Divider(height: 20, color: tk.border), kv(context.str('pos_posreceiptscreen_label_paid_via'), r.paymentMethod)],
    ]);

    final timelineCard = r.timeline.isEmpty
        ? null
        : card('pos_posorderdetailscreen_timeline', [
      for (var i = 0; i < r.timeline.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: i == r.timeline.length - 1 ? context.primary : tk.border, shape: BoxShape.circle)), if (i < r.timeline.length - 1) Container(width: 2, height: 26, color: tk.border)]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.timeline[i].value, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)), Text([if (r.timeline[i].time.isNotEmpty) posDateTime(context, r.timeline[i].time), if (r.timeline[i].location.isNotEmpty) r.timeline[i].location].join('  ·  '), style: TextStyle(fontSize: 12.5, color: tk.text3))])),
          ]),
        ),
    ]);

    final staffCard = card(null, [
      kv(context.str('pos_posstaffscreen_staff'), r.cashier),
      kv(context.str('pos_posstaffscreen_shift'), r.sessionId),
      kv(context.str('pos_posstoreprofilescreen_session_terminal'), r.terminal),
    ]);

    // ══ phone: exactly what it was (one column, the buttons at the bottom) ════
    if (!wide) {
      final body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(children: [
            Expanded(child: Text('# ${r.orderNumber}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1))),
            PosStatusBadge(status: r.status, serverText: r.statusText),
          ]),
          const SizedBox(height: 4),
          if (r.date.isNotEmpty) Text(posDateTime(context, r.date), style: TextStyle(color: tk.text2)),
          const SizedBox(height: 12),
          customerCard,
          const SizedBox(height: 12),
          itemsCard,
          const SizedBox(height: 12),
          paymentCard,
          if (timelineCard != null) ...[const SizedBox(height: 12), timelineCard],
          const SizedBox(height: 12),
          staffCard,
          const SizedBox(height: 18),
          if (canNext) FilledButton(onPressed: _busy ? null : () => _advance(repo, next), style: FilledButton.styleFrom(minimumSize: const Size(0, 54), backgroundColor: toneColor(context, toneOf(next))), child: Text(context.str(nextKey))),
          if (cancellable) ...[const SizedBox(height: 10), OutlinedButton(onPressed: _busy ? null : () => _cancel(repo), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), foregroundColor: tk.danger, side: BorderSide(color: tk.danger)), child: Text(context.str('pos_posorderdetailscreen_cancel_order_button')))],
          if (done) ...[
            FilledButton.icon(onPressed: () => context.push('${Routes.posReceipt}/${Uri.encodeComponent(r.orderId)}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), icon: const Icon(Icons.print_outlined), label: Text(context.str('pos_posorderdetailscreen_reprint'))),
            if (lines.isNotEmpty) ...[const SizedBox(height: 10), OutlinedButton(onPressed: () => _reorder(lines), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), child: Text(context.str('pos_posreceiptscreen_new_order')))],
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 3)),
        ],
      );
      return PosPage(title: context.str('pos_posordersscreen_title'), back: Routes.posOrders, child: RefreshIndicator(onRefresh: refresh, child: body));
    }

    // ══ tablet and browser: the buttons in the page header, two columns below ═
    final actions = <Widget>[
      if (cancellable) OutlinedButton(onPressed: _busy ? null : () => _cancel(repo), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: tk.danger, side: BorderSide(color: tk.danger)), child: Text(context.str('pos_posorderdetailscreen_cancel_order_button'))),
      if (canNext) FilledButton(onPressed: _busy ? null : () => _advance(repo, next), style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: toneColor(context, toneOf(next))), child: Text(context.str(nextKey))),
      if (done && lines.isNotEmpty) OutlinedButton(onPressed: () => _reorder(lines), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(context.str('pos_posreceiptscreen_new_order'))),
      if (done) FilledButton.icon(onPressed: () => context.push('${Routes.posReceipt}/${Uri.encodeComponent(r.orderId)}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.print_outlined, size: 20), label: Text(context.str('pos_posorderdetailscreen_reprint'))),
    ];

    final body = LayoutBuilder(builder: (context, box) {
      Widget stack(List<Widget> cards) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 16), cards[i]]]);
      final left = <Widget>[itemsCard, paymentCard];
      final right = <Widget>[customerCard, ?timelineCard, staffCard];
      final two = box.maxWidth >= 760;
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 3)),
            if (two)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: stack(left)), const SizedBox(width: 16), Expanded(flex: 5, child: stack(right))])
            else
              stack([customerCard, itemsCard, paymentCard, ?timelineCard, staffCard]),
          ],
        ),
      );
    });

    // the title carries the status: "# 1042" and its badge, the date and the terminal under it
    return PosPage(
      title: '# ${r.orderNumber}',
      subtitle: [if (r.date.isNotEmpty) posDateTime(context, r.date), if (r.terminal.isNotEmpty) r.terminal].join(' · '),
      back: Routes.posOrders,
      actions: [PosStatusBadge(status: r.status, serverText: r.statusText), ...actions],
      child: body,
    );
  }
}

typedef PosOrdersRepositoryRef = PosOrdersRepository;
typedef PosOrderLines = List<({PosProduct product, PosVariant variant, List<PosModifierContent> modifiers, int qty})>;