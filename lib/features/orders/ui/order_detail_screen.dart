import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/ui/brand_widgets.dart';
import '../data/order_detail_models.dart';
import '../logic/order_actions.dart';
import '../logic/order_detail_provider.dart';
import 'order_action_widgets.dart';

const _kWideWidth = 880.0;
const _kMaxWidth = 1100.0;

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(orderDetailProvider(widget.id));
  }

  Future<void> _refresh() async {
    ref.invalidate(orderDetailProvider(widget.id));
    try {
      await ref.read(orderDetailProvider(widget.id).future);
    } catch (_) {} // the error shows on screen
  }

  /// Also works when the page was opened by a direct link (nothing to pop).
  void _back() => context.canPop() ? context.pop() : context.go(Routes.orders);

  /// Runs one action, shows the server's message, and reports a refusal in red.
  Future<bool> _run(String action, {List<int> driverIds = const []}) async {
    try {
      final message = await ref.read(orderActionsProvider.notifier).perform(widget.id, action, driverIds: driverIds);
      if (mounted && message.isNotEmpty) showAppSnack(context, message);
      return true;
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
      return false;
    }
  }

  Future<void> _onAction(OrderAction a) async {
    final d = ref.read(orderDetailProvider(widget.id)).value;
    if (d == null) return;
    final act = OrderActions.normalize(a.action);

    if (act == OrderActions.assign) {
      final mode = await showAssignModeDialog(context);
      if (mode == null || !mounted) return;
      if (mode == AssignMode.automatic) {
        await _run(OrderActions.autoAssign);
      } else {
        final ids = await showDriverPicker(context, orderId: widget.id, number: d.number);
        if (ids != null && ids.isNotEmpty && mounted) await _run(OrderActions.manualAssign, driverIds: ids);
      }
      return;
    }

    if (OrderActions.isPickup(act)) {
      final message = await showPickupOtpDialog(context, widget.id);
      if (message != null && message.isNotEmpty && mounted) showAppSnack(context, message);
      return;
    }

    if (act == OrderActions.reject && !await confirmAction(context, a.text)) return;
    if (!mounted) return;
    final ok = await _run(act);
    if (ok && act == OrderActions.reject && mounted) _back(); // a rejected order leaves this list
  }
  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final brand = context.primary;
    final on = onColor(brand);
    final async = ref.watch(orderDetailProvider(widget.id));
    final d = async.value;
    final wide = MediaQuery.sizeOf(context).width >= _kWideWidth;
    final actions = d == null ? const <OrderAction>[] : OrderActions.visible(d.actions);
    final busy = ref.watch(orderActionsProvider);

    Widget body;
    if (d != null) {
      body = _Body(d: d, wide: wide);
    } else if (async.hasError) {
      body = _ErrorCard(message: errorText(async.error!, ref.read(stringsProvider)), onRetry: _refresh);
    } else {
      body = const SkeletonPulse(
        child: Column(children: [SkeletonBox(height: 190, radius: 16), SizedBox(height: 12), SkeletonBox(height: 120, radius: 16), SizedBox(height: 12), SkeletonBox(height: 120, radius: 16)]),
      );
    }

    final page = Scaffold(
      backgroundColor: tk.canvas,
      bottomNavigationBar: (!wide && actions.isNotEmpty) ? OrderActionBar(actions: actions, busy: busy, onTap: _onAction) : null,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _Header(
              d: d,
              wide: wide,
              onBack: _back,
              actions: (wide && actions.isNotEmpty) ? HeaderActions(actions: actions, busy: busy, onTap: _onAction) : null,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxWidth),
                child: Padding(padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32), child: body),
              ),
            ),
          ],
        ),
      ),
    );

    if (wide) return page;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: on == Colors.white ? Brightness.light : Brightness.dark,
        statusBarBrightness: on == Colors.white ? Brightness.dark : Brightness.light,
      ),
      child: page,
    );
  }
}

// ── brand header (option C) ──────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.d, required this.wide, required this.onBack, this.actions});
  final OrderDetail? d;
  final bool wide;
  final VoidCallback onBack;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);
    final top = MediaQuery.paddingOf(context).top;

    Widget shimmer(double w, double h) => SkeletonPulse(
      child: Container(width: w, height: h, decoration: BoxDecoration(color: on.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8))),
    );

    final meta = d == null
        ? null
        : [d!.orderTime, if (d!.totalItems > 0) '${d!.totalItems} ${context.str('orders_ordersscreen_items_title').replaceAll(RegExp(r':\s*$'), '')}']
        .where((e) => e.isNotEmpty)
        .join('  ·  ');

    final steps = d?.timeline ?? const <TimelineStep>[];

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(wide ? 0 : 28)),
      child: ColoredBox(
        color: brand,
        child: BrandBackdrop(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 16 : top + 8, wide ? 24 : 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: onBack,
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
                          icon: Icon(Icons.arrow_back_rounded, color: on),
                        ),
                        const Spacer(),
                        if (d != null && d!.invoiceUrl.isNotEmpty)
                          IconButton(
                            tooltip: context.str('orders_ordersscreen_invoice_title_text'),
                            style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
                            onPressed: () {
                              final uri = Uri.tryParse(d!.invoiceUrl);
                              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            icon: Icon(Icons.receipt_long_rounded, color: on),
                          ),
                        if (actions != null) ...[
                          const SizedBox(width: 12),
                          Flexible(child: actions!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (d == null) ...[
                      shimmer(150, 30),
                      const SizedBox(height: 10),
                      shimmer(220, 14),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('#${d!.number}', style: TextStyle(color: on, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                          if (d!.statusText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: on.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(50)),
                              child: Text(d!.statusText, style: TextStyle(color: on, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      if (meta != null && meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(meta, style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 14)),
                      ],
                      if (d!.deliverOn.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delivery_dining_rounded, size: 16, color: on.withValues(alpha: 0.9)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(d!.deliverOn, style: TextStyle(color: on.withValues(alpha: 0.9), fontSize: 13))),
                          ],
                        ),
                      ],
                      if (steps.length > 1) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            for (var i = 0; i < steps.length; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: Motion.base,
                                  height: 5,
                                  decoration: BoxDecoration(color: steps[i].done ? on : on.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.d, required this.wide});

  final OrderDetail d;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);

    final left = <Widget>[
      _ItemsCard(d: d),
      if (d.timeline.isNotEmpty) _TimelineCard(steps: d.timeline),
      if (d.cooking.isNotEmpty) _NoteCard(titleKey: 'orders_ordersscreen_cooking_instructions_title', text: d.cooking, icon: Icons.soup_kitchen_rounded),
      if (d.instructionOptions.isNotEmpty) _InstructionsCard(options: d.instructionOptions),
      if (d.notes.isNotEmpty) _NoteCard(titleKey: 'orders_orderdetail_additional_notes_title', text: d.notes, icon: Icons.sticky_note_2_outlined),
    ];
    final right = <Widget>[
      if (d.customer != null) _CustomerCard(c: d.customer!),
      _PaymentCard(p: d.payment),
      if (d.driver != null) _DriverCard(dr: d.driver!),
    ];

    Widget column(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) gap, items[i]]],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 16, child: column(left)),
          const SizedBox(width: 12),
          Expanded(flex: 10, child: column(right)),
        ],
      );
    }
    // phone: items, then the people, then the rest
    return column([left.first, ...right, ...left.skip(1)]);
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: context.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tk.text1))),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(16), child: child));
}

// ── items + bill (receipt) ───────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.d});

  final OrderDetail d;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.shopping_bag_outlined, context.str('orders_orderdetail_order_items_title')),
          for (var i = 0; i < d.lines.length; i++) ...[
            if (i > 0) Divider(height: 22, color: tk.border),
            _LineTile(line: d.lines[i]),
          ],
          if (d.bill.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Dashed(color: tk.border),
            const SizedBox(height: 12),
            for (final b in d.bill)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(b.name, style: TextStyle(fontSize: b.bold ? 15 : 13.5, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w500, color: b.bold ? tk.text1 : tk.text2))),
                    Text(b.value, style: TextStyle(fontSize: b.bold ? 16 : 13.5, fontWeight: b.bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.fastfood_outlined, size: 22, color: tk.text3),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: line.image.isEmpty
              ? placeholder
              : CachedNetworkImage(imageUrl: line.image, width: 48, height: 48, fit: BoxFit.cover, memCacheWidth: 150, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1, height: 1.3)),
              if (line.variant.isNotEmpty) Text(line.variant, style: TextStyle(fontSize: 12.5, color: tk.text2)),
              Text('${context.str('orders_orderdetail_item_qty_prefix')}${line.quantity}', style: TextStyle(fontSize: 12.5, color: tk.text3)),
              for (final o in line.options)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('+ ${o.name}', style: TextStyle(fontSize: 12.5, color: tk.text2))),
                      if (o.amount.isNotEmpty) Text(o.amount, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                    ],
                  ),
                ),
              if (line.hasDiscount) Padding(padding: const EdgeInsets.only(top: 2), child: Text(line.discount, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tk.success))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(line.value, style: TextStyle(fontWeight: line.bold ? FontWeight.w800 : FontWeight.w700, color: tk.text1)),
      ],
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final n = (box.maxWidth / 8).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < n; i++) Container(width: 4, height: 1.5, color: color)],
      );
    },
  );
}

// ── timeline ─────────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final loc = MaterialLocalizations.of(context);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.local_shipping_outlined, context.str('orders_orderdetail_order_status_title')),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        _StepIcon(step: steps[i]),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: steps[i].done ? context.primary.withValues(alpha: 0.4) : tk.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(child: Text(steps[i].text, style: TextStyle(fontWeight: steps[i].done ? FontWeight.w700 : FontWeight.w500, color: steps[i].done ? tk.text1 : tk.text3))),
                          if (steps[i].at != null) Text(loc.formatTimeOfDay(TimeOfDay.fromDateTime(steps[i].at!)), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step});

  final TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final fallback = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: step.done ? context.primary : tk.sunken, shape: BoxShape.circle, border: step.done ? null : Border.all(color: tk.border)),
      child: step.done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
    if (step.icon.isEmpty) return fallback;
    return CachedNetworkImage(imageUrl: step.icon, width: 26, height: 26, memCacheWidth: 80, placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback);
  }
}

// ── people, payment, notes ───────────────────────────────────────────────────

Future<void> _call(String phone) async {
  final p = phone.trim();
  if (p.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: p));
}

class _CallButton extends StatelessWidget {
  const _CallButton(this.phone);

  final String phone;

  @override
  Widget build(BuildContext context) => phone.trim().isEmpty
      ? const SizedBox.shrink()
      : FilledButton.tonalIcon(
    onPressed: () => _call(phone),
    icon: const Icon(Icons.call_rounded, size: 18),
    label: Text(context.str('orders_ordersscreen_callLabel')),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: context.primary.withValues(alpha: 0.12),
    child: Text(name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: context.primary)),
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.c});

  final CustomerInfo c;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.person_outline_rounded, context.str('orders_ordersscreen_customerInfo')),
          Row(
            children: [
              _Avatar(c.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                    Text(c.phone.isEmpty ? context.str('orders_ordersscreen_customer_role') : c.phone, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  ],
                ),
              ),
              _CallButton(c.phone),
            ],
          ),
          if (c.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: tk.text2),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.address, style: TextStyle(fontSize: 13, color: tk.text1, height: 1.35))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: c.address));
                      if (context.mounted) showAppSnack(context, c.address);
                    },
                    icon: Icon(Icons.copy_rounded, size: 18, color: tk.text2),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.p});

  final PaymentInfo p;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: tk.text2))), value]),
    );
    final total = [p.currency, p.amount].where((e) => e.isNotEmpty).join(' ');
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.payments_outlined, context.str('orders_orderdetail_payment_details_title')),
          if (p.paidStatus.isNotEmpty)
            row(
              context.str('orders_orderdetail_payment_status_label'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
                child: Text(p.paidStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.success)),
              ),
            ),
          if (p.mode.isNotEmpty) row(context.str('orders_ordersscreen_payment_method_title'), Text(p.mode, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1))),
          if (total.isNotEmpty) ...[
            Divider(height: 18, color: tk.border),
            row(context.str('orders_orderdetail_total_amount_label'), Text(total, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1))),
          ],
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.dr});

  final DriverInfo dr;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.delivery_dining_rounded, context.str('orders_ordersscreen_delivery_driver_title')),
          Row(
            children: [
              _Avatar(dr.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dr.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                    if (dr.rating.isNotEmpty)
                      Row(children: [Icon(Icons.star_rounded, size: 16, color: tk.warning), const SizedBox(width: 3), Text(dr.rating, style: TextStyle(fontSize: 12.5, color: tk.text2))]),
                  ],
                ),
              ),
              _CallButton(dr.phone),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.titleKey, required this.text, required this.icon});

  final String titleKey;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _Section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardTitle(icon, context.str(titleKey)),
        SelectableText(text, style: TextStyle(color: context.tk.text1, height: 1.45)),
      ],
    ),
  );
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.options});

  final List<String> options;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(Icons.checklist_rounded, context.str('orders_ordersscreen_additional_instructions_title')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(50)),
                  child: Text(o, style: TextStyle(fontSize: 12.5, color: tk.text1)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
          ],
        ),
      ),
    );
  }
}