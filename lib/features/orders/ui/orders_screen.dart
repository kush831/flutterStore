import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/order_models.dart';
import '../logic/order_tabs.dart';
import '../logic/orders_controller.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.tabParam});

  /// ?tab=new | ongoing | upcoming | cancelled | rejected | expired | completed
  final String? tabParam;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with WidgetsBindingObserver {
  late OrderTab _tab = OrderTab.fromParam(widget.tabParam);
  String? _sub; // the chosen sub-filter's status, or null

  String get _status => _sub ?? _tab.status;

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
  void didUpdateWidget(OrdersScreen old) {
    super.didUpdateWidget(old);
    // Home → Orders?tab=completed while Orders is already open
    if (old.tabParam != widget.tabParam) {
      setState(() {
        _tab = OrderTab.fromParam(widget.tabParam);
        _sub = null;
      });
      _refreshIfLoaded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(); // back from the background
  }

  void _refresh() => ref.read(ordersProvider(_status).notifier).refresh();

  /// Re-entering a tab shows what it had at once and refreshes quietly.
  void _refreshIfLoaded() {
    if (ref.read(ordersProvider(_status)).loadedOnce) _refresh();
  }

  void _selectTab(OrderTab t) {
    if (t == _tab) {
      _refresh();
      return;
    }
    setState(() {
      _tab = t;
      _sub = null;
    });
    _refreshIfLoaded();
  }

  void _selectSub(OrderSub s) {
    setState(() => _sub = _status == s.status ? null : s.status);
    _refreshIfLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final expireMinutes = ref.watch(dashboardProvider.select((s) => s.home.value?.orderExpireTime ?? 0));
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final title = context.str('orders_ordersscreen_title');

    final parts = <Widget>[
      _Tabs(selected: _tab, onSelect: _selectTab, compact: compact),
      if (_tab.subs.isNotEmpty) _SubFilters(tab: _tab, selectedStatus: _status, onSelect: _selectSub, compact: compact),
      Expanded(
        child: _OrdersContent(
          key: ValueKey(_status), // a new status starts with a fresh "expired" set
          status: _status,
          tone: _tab.toneFor(_status),
          showExpiry: _tab == OrderTab.newOrders && _status == 'TODAY',
          expireMinutes: expireMinutes,
          currency: currency,
          compact: compact,
        ),
      ),
    ];

    if (compact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1)),
              ),
              ...parts,
            ],
          ),
        ),
      );
    }

    return AdaptivePage(
      title: title,
      actions: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          onPressed: _refresh,
          icon: Icon(Icons.refresh_rounded, color: tk.text2),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: parts),
    );
  }
}

// ── tabs ─────────────────────────────────────────────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect, required this.compact});

  final OrderTab selected;
  final ValueChanged<OrderTab> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0, vertical: 10),
        children: [
          for (final t in OrderTab.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                button: true,
                selected: t == selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => onSelect(t),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == selected ? primary : tk.surface,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: t == selected ? primary : tk.border),
                    ),
                    child: Text(
                      context.str(t.labelKey),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t == selected ? Colors.white : tk.text2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubFilters extends StatelessWidget {
  const _SubFilters({required this.tab, required this.selectedStatus, required this.onSelect, required this.compact});

  final OrderTab tab;
  final String selectedStatus;
  final ValueChanged<OrderSub> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0, vertical: 4),
        children: [
          for (final s in tab.subs)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.status == selectedStatus ? primary.withValues(alpha: 0.12) : tk.sunken,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.str(s.labelKey),
                    style: TextStyle(fontSize: 12.5, fontWeight: s.status == selectedStatus ? FontWeight.w700 : FontWeight.w500, color: s.status == selectedStatus ? primary : tk.text2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── the list ─────────────────────────────────────────────────────────────────

class _OrdersContent extends ConsumerStatefulWidget {
  const _OrdersContent({
    super.key,
    required this.status,
    required this.tone,
    required this.showExpiry,
    required this.expireMinutes,
    required this.currency,
    required this.compact,
  });

  final String status;
  final OrderTone tone;
  final bool showExpiry;
  final int expireMinutes;
  final String currency;
  final bool compact;

  @override
  ConsumerState<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends ConsumerState<_OrdersContent> {
  final _expired = <int>{};

  void _open(OrderItem o) => context.push(Routes.orderDetail('${o.id}'));

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(ordersProvider(widget.status));
    final ctrl = ref.read(ordersProvider(widget.status).notifier);
    final items = [for (final o in st.items) if (!_expired.contains(o.id)) o];

    if (st.showShimmer) return const _ListSkeleton();
    if (st.showError) return _MessageView(icon: Icons.cloud_off_rounded, titleKey: 'common_allscreen_something_went_wrong', onRetry: ctrl.refresh);
    if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      return RefreshIndicator(
        color: context.primary,
        onRefresh: ctrl.refresh,
        child: const _MessageView(
          icon: Icons.receipt_long_outlined,
          titleKey: 'emptystate_emptystate_no_orders_title',
          messageKey: 'emptystate_emptystate_no_orders_message1',
          scrollable: true,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final table = w >= 760;
        final grid = !table && w >= 520;
        final pad = widget.compact ? 16.0 : 0.0;

        Widget card(OrderItem o) => _OrderCard(
          o: o,
          tone: widget.tone,
          currency: widget.currency,
          expiresAt: widget.showExpiry ? o.expiresAt(widget.expireMinutes) : null,
          onExpired: () => setState(() => _expired.add(o.id)),
          onTap: () => _open(o),
        );

        final slivers = <Widget>[
          if (table) ...[
            const SliverToBoxAdapter(child: _TableHeader()),
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _OrderRow(
                o: items[i],
                tone: widget.tone,
                currency: widget.currency,
                expiresAt: widget.showExpiry ? items[i].expiresAt(widget.expireMinutes) : null,
                onExpired: () => setState(() => _expired.add(items[i].id)),
                onTap: () => _open(items[i]),
              ),
            ),
          ] else if (grid)
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 138),
              itemCount: items.length,
              itemBuilder: (_, i) => card(items[i]),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => card(items[i]),
              ),
            ),
          SliverToBoxAdapter(child: _Footer(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ];

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 500) ctrl.loadMore(); // PagedNotifier ignores it when there is nothing more
            return false;
          },
          child: RefreshIndicator(
            color: context.primary,
            onRefresh: ctrl.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: widget.compact ? 4 : 8)), ...slivers],
            ),
          ),
        );
      },
    );
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

Color _toneColor(BuildContext context, OrderTone t) {
  final tk = context.tk;
  return switch (t) {
    OrderTone.info => tk.info,
    OrderTone.warning => tk.warning,
    OrderTone.success => tk.success,
    OrderTone.danger => tk.danger,
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.tone});

  final String text;
  final OrderTone tone;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final c = _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

/// "Paid" mark: a readable label from the server, or just an icon for 0/1 values.
class _PaidMark extends StatelessWidget {
  const _PaidMark(this.o);

  final OrderItem o;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (o.paidIsLabel) {
      return Text(o.paid, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tk.text2));
    }
    return switch (o.paidState) {
      PaidState.paid => Icon(Icons.check_circle_rounded, size: 16, color: tk.success),
      PaidState.unpaid => Icon(Icons.schedule_rounded, size: 16, color: tk.warning),
      PaidState.unknown => const SizedBox.shrink(),
    };
  }
}

class _ExpiryChip extends StatefulWidget {
  const _ExpiryChip({required this.expiresAt, required this.onExpired});

  final DateTime expiresAt;
  final VoidCallback onExpired;

  @override
  State<_ExpiryChip> createState() => _ExpiryChipState();
}

class _ExpiryChipState extends State<_ExpiryChip> {
  Timer? _timer;
  late Duration _left = widget.expiresAt.difference(DateTime.now());
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _check();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _left = widget.expiresAt.difference(DateTime.now()));
    _check();
  }

  void _check() {
    if (_left > Duration.zero || _fired) return;
    _fired = true;
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired(); // the order leaves the New tab
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final left = _left.isNegative ? Duration.zero : _left;
    final text = '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final c = left.inSeconds < 60 ? tk.danger : tk.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: c),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.o, required this.tone, required this.currency, required this.expiresAt, required this.onExpired, required this.onTap});

  final OrderItem o;
  final OrderTone tone;
  final String currency;
  final DateTime? expiresAt;
  final VoidCallback onExpired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('#${o.number}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
                        if (expiresAt != null) _ExpiryChip(expiresAt: expiresAt!, onExpired: onExpired),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150), // lamba text "…" ke saath kat jaye
                    child: _StatusPill(text: o.statusText, tone: tone),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(o.items, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: tk.text2, height: 1.35)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: tk.text3),
                  const SizedBox(width: 4),
                  Expanded(child: Text(o.time.isEmpty ? o.date : o.time, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text3))),
                  _PaidMark(o),
                  const SizedBox(width: 6),
                  Text(money(currency, o.amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
                ],
              ),
              if (o.paymentMode.isNotEmpty) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(o.paymentMode, style: TextStyle(fontSize: 11.5, color: tk.text3)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── table (wide) ─────────────────────────────────────────────────────────────

const _cols = <int>[12, 30, 17, 16, 12, 14]; // flex of: #, items, date/time, payment, amount, status

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.text2);
    String label(String key) => context.str(key).replaceAll(RegExp(r':\s*$'), '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tk.sunken,
        border: Border(top: BorderSide(color: tk.border), bottom: BorderSide(color: tk.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
      ),
      child: Row(
        children: [
          Expanded(flex: _cols[0], child: Text('#', style: style)),
          Expanded(flex: _cols[1], child: Text(label('orders_ordersscreen_items_title'), style: style)),
          Expanded(flex: _cols[2], child: Icon(Icons.schedule_rounded, size: 16, color: tk.text2)),
          Expanded(flex: _cols[3], child: Text(label('orders_ordersscreen_payment_title'), style: style)),
          Expanded(flex: _cols[4], child: Text(label('orders_orderdetail_total_amount_label'), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: 16),
          Expanded(flex: _cols[5], child: Text(label('orders_orderdetail_order_status_title'), textAlign: TextAlign.end,maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.o, required this.tone, required this.currency, required this.expiresAt, required this.onExpired, required this.onTap});

  final OrderItem o;
  final OrderTone tone;
  final String currency;
  final DateTime? expiresAt;
  final VoidCallback onExpired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
          child: Row(
            children: [
              Expanded(
                flex: _cols[0],
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('#${o.number}', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                    if (expiresAt != null) _ExpiryChip(expiresAt: expiresAt!, onExpired: onExpired),
                  ],
                ),
              ),
              Expanded(flex: _cols[1], child: Text(o.items, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2, height: 1.35))),
              Expanded(flex: _cols[2], child: Text([o.date, o.time].where((e) => e.isNotEmpty).join('  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
              Expanded(
                flex: _cols[3],
                child: Row(children: [
                  Flexible(child: Text(o.paymentMode, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
                  const SizedBox(width: 6),
                  _PaidMark(o),
                ]),
              ),
              Expanded(flex: _cols[4], child: Text(money(currency, o.amount), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
              const SizedBox(width: 16),
              Expanded(flex: _cols[5], child: Align(alignment: AlignmentDirectional.centerEnd, child: _StatusPill(text: o.statusText, tone: tone))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── states ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.hasMore, required this.loading, required this.failed, required this.onRetry});

  final bool hasMore;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(child: TextButton(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))),
      );
    }
    if (loading || hasMore) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    }
    return const SizedBox.shrink();
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 104, radius: 14))],
    ),
  );
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.titleKey, this.messageKey, this.onRetry, this.scrollable = false});

  final IconData icon;
  final String titleKey;
  final String? messageKey;
  final Future<void> Function()? onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final body = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: tk.text3),
          const SizedBox(height: 16),
          Text(context.str(titleKey), textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
          if (messageKey != null) ...[
            const SizedBox(height: 6),
            Text(context.str(messageKey!).replaceAll(RegExp(r'\\+n'), '\n'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45)),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
          ],
        ],
      ),
    );
    if (scrollable) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 60), body]);
    }
    return Center(child: body);
  }
}