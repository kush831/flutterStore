import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/dashboard_models.dart';
import '../logic/dashboard_controller.dart';
import 'home_format.dart';

const _kDesktopWidth = 880.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
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
    // back from the background: numbers may be old
    if (state == AppLifecycleState.resumed) ref.read(dashboardProvider.notifier).refresh();
  }

  Future<void> _membershipDialog(String message) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.workspace_premium_rounded, size: 40, color: ctx.primary),
        title: Text(ctx.str('settings_settings_row_memberShip')),
        content: Text(message.isEmpty ? ctx.str('settings_settings_row_memberShipDesc') : message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.str('settings_settings_row_memberShip'))),
        ],
      ),
    );
    if (go == true && mounted) context.push(Routes.membership);
  }

  Future<void> _toggle(bool open) async {
    final err = await ref.read(dashboardProvider.notifier).toggleOpen(open);
    if (err != null && mounted) showAppSnack(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(dashboardProvider);
    final ctrl = ref.read(dashboardProvider.notifier);
    final size = context.screen;
    final data = st.home.value;

    // the "membership expired" popup: once per session, only when a subscription is needed
    ref.listen<DashboardData?>(dashboardProvider.select((s) => s.home.value), (_, d) {
      if (d != null && d.membershipNeeded && !ref.read(dashboardProvider).popupShown) {
        ctrl.markPopupShown();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _membershipDialog(d.subscriptionMessage);
        });
      }
    });

    final greeting = context.str(greetingKeyFor(DateTime.now().hour));
    final subtitle = data == null ? '' : context.str('main_storedashboard_subtitle').replaceAll('{store_name}', data.storeName);

    final badge = (data?.membershipNeeded ?? false)
        ? PositionedDirectional(
      end: 16,
      bottom: 16,
      child: Material(
        color: context.primary,
        borderRadius: BorderRadius.circular(50),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () => context.push(Routes.membership),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(context.str('settings_settings_row_memberShip'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    )
        : const Positioned(top: 0, left: 0, child: SizedBox.shrink());

    Widget list(double width) => RefreshIndicator(
      color: context.primary,
      onRefresh: ctrl.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(size.isCompact ? 16 : 0, size.isCompact ? 8 : 0, size.isCompact ? 16 : 0, 96),
        children: [
          if (size.isCompact) ...[
            GestureDetector(
              onLongPress: AppEnv.devTools ? () => context.push(Routes.devStrings) : null,
              child: _Greeting(greeting: greeting, subtitle: subtitle),
            ),
            const SizedBox(height: 16),
            if (data != null) ...[_StoreCard(d: data), const SizedBox(height: 12)],
            _StatusCard(isOpen: st.isOpen, updating: st.updating, loading: st.home.isLoading && data == null, onChanged: _toggle),
            const SizedBox(height: 12),
          ],
          ..._sections(context, st, width >= _kDesktopWidth ? _Mode.desktop : (size.isCompact ? _Mode.compact : _Mode.medium)),
        ],
      ),
    );

    if (size.isCompact) {
      return Scaffold(
        backgroundColor: context.tk.canvas,
        body: SafeArea(
          bottom: false,
          child: Stack(children: [Positioned.fill(child: list(0)), badge]),
        ),
      );
    }

    return AdaptivePage(
      title: greeting,
      subtitle: subtitle.isEmpty ? null : subtitle,
      actions: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          onPressed: ctrl.refresh,
          icon: Icon(Icons.refresh_rounded, color: context.tk.text2),
        ),
      ],
      child: LayoutBuilder(builder: (context, box) => Stack(children: [Positioned.fill(child: list(box.maxWidth)), badge])),
    );
  }

  List<Widget> _sections(BuildContext context, DashboardState st, _Mode mode) {
    final home = st.home;
    final data = home.value;
    final loadingHome = home.isLoading && data == null;
    const gap = SizedBox(height: 12);

    final Widget counts;
    final Widget sales;
    final Widget alerts;
    if (home.hasError && data == null) {
      final err = _ErrorCard(message: errorText(home.error!, ref.read(stringsProvider)), onRetry: ref.read(dashboardProvider.notifier).refresh);
      counts = err;
      sales = const SizedBox.shrink();
      alerts = const SizedBox.shrink();
    } else if (loadingHome) {
      counts = const _CountsSkeleton();
      sales = const SkeletonPulse(child: SkeletonBox(height: 104, radius: 16));
      alerts = const SizedBox.shrink();
    } else {
      final d = data!;
      counts = _Counts(d: d, withSalesToday: mode == _Mode.desktop);
      sales = _SalesCard(d: d);
      alerts = Column(
        children: [
          if (d.outOfStock > 0)
            _AlertTile(
              tone: _AlertTone.danger,
              icon: Icons.error_outline_rounded,
              title: context.str('main_storedashboard_out_of_stock_title'),
              message: '${d.outOfStock} ${context.str('main_storedashboard_out_of_stock_message')}',
              onTap: () => context.push(Routes.manageStock),
            ),
          if (d.outOfStock > 0 && d.lowStock > 0) const SizedBox(height: 8),
          if (d.lowStock > 0)
            _AlertTile(
              tone: _AlertTone.warning,
              icon: Icons.warning_amber_rounded,
              title: context.str('main_storedashboard_low_stock_alert_title'),
              message: '${d.lowStock} ${context.str('main_storedashboard_low_stock_alert_message')}',
              onTap: () => context.push(Routes.manageStock),
            ),
        ],
      );
    }

    final summary = st.summary.when(
      data: (s) => _SummaryCard(s: s, currency: data?.currency ?? ''),
      loading: () => const SkeletonPulse(child: SkeletonBox(height: 220, radius: 16)),
      error: (e, _) => _ErrorCard(message: errorText(e, ref.read(stringsProvider)), onRetry: ref.read(dashboardProvider.notifier).refresh),
    );

    if (mode == _Mode.desktop) {
      return [
        if (data != null) ...[_StoreCard(d: data), gap],
        counts,
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 16, child: Column(children: [sales, gap, summary])),
            const SizedBox(width: 12),
            Expanded(flex: 10, child: Column(children: [alerts, if (data != null && (data.outOfStock > 0 || data.lowStock > 0)) gap, const _QuickActions()])),
          ],
        ),
      ];
    }

    return [
      if (mode != _Mode.compact && data != null) ...[_StoreCard(d: data), gap],
      counts,
      gap,
      sales,
      if (data != null && (data.outOfStock > 0 || data.lowStock > 0)) ...[gap, alerts],
      gap,
      const _QuickActions(),
      gap,
      summary,
    ];
  }
}

enum _Mode { compact, medium, desktop }

// ── pieces ───────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.greeting, required this.subtitle});

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: tk.text2, height: 1.4)),
        ],
      ],
    );
  }
}

/// Phone only: on wide screens the same switch is in the top bar of the app frame.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isOpen, required this.updating, required this.loading, required this.onChanged});

  final bool? isOpen;
  final bool updating;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (loading) return const SkeletonPulse(child: SkeletonBox(height: 76, radius: 16));
    final open = isOpen ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: open ? tk.successBg : tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(Icons.storefront_rounded, color: open ? tk.success : tk.danger),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.str('main_storedashboard_store_status_title'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  Text(
                    open ? context.str('main_storedashboard_store_status_open') : context.str('main_storedashboard_store_status_closed'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: open ? tk.success : tk.danger),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              height: 40,
              child: Center(
                child: updating
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.primary))
                    : Switch(value: open, onChanged: onChanged),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The store header: profile image, name and address. Tapping it opens the store profile.
class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.d});

  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final initial = d.storeName.trim().isEmpty ? '·' : d.storeName.trim()[0].toUpperCase();
    final fallback = Container(
      width: 56,
      height: 56,
      color: context.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary)),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.storeProfile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: d.profileImage.isEmpty
                    ? fallback
                    : CachedNetworkImage(
                  imageUrl: d.profileImage,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  memCacheWidth: 170,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
                    if (d.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.location_on_outlined, size: 15, color: tk.text3)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(d.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.35))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tk.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.d, required this.withSalesToday});

  final DashboardData d;
  final bool withSalesToday;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget card(String label, String value, Color color, VoidCallback onTap) => _StatCard(label: label, value: value, color: color, onTap: onTap);

    final cards = [
      card(context.str('main_storedashboard_pending_title'), '${d.pending}', tk.warning, () => context.go(Routes.ordersTab('new'))),
      card(context.str('main_storedashboard_in_progress_title'), '${d.inProgress}', tk.info, () => context.go(Routes.ordersTab('ongoing'))),
      card(context.str('main_storedashboard_completed_title'), '${d.completed}', tk.success, () => context.go(Routes.ordersTab('completed'))),
      if (withSalesToday) _StatCard(label: context.str('main_storedashboard_sales_today_title'), value: money(d.currency, d.salesToday), color: context.tk.text1),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, this.onTap});

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountsSkeleton extends StatelessWidget {
  const _CountsSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
    child: Row(children: [
      Expanded(child: SkeletonBox(height: 84, radius: 16)),
      SizedBox(width: 12),
      Expanded(child: SkeletonBox(height: 84, radius: 16)),
      SizedBox(width: 12),
      Expanded(child: SkeletonBox(height: 84, radius: 16)),
    ]),
  );
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.d});

  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final rows = <(String, String)>[
      (context.str('main_storedashboard_sales_today_title'), d.salesToday),
      (context.str('main_storedashboard_sales_week_title'), d.salesWeek),
      (context.str('main_storedashboard_sales_month_title'), d.salesMonth),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.str('main_storedashboard_sales_summary_title'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: tk.border),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Table(
                columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.3)},
                border: TableBorder.symmetric(inside: BorderSide(color: tk.border)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (final (label, value) in rows)
                    TableRow(
                      children: [
                        Container(
                          color: tk.sunken,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text2)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Text(
                            money(d.currency, value),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AlertTone { danger, warning }

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.tone, required this.icon, required this.title, required this.message, required this.onTap});

  final _AlertTone tone;
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (fg, bg) = tone == _AlertTone.danger ? (tk.danger, tk.dangerBg) : (tk.warning, tk.warningBg);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
                    Text(message, style: TextStyle(fontSize: 13, color: fg)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final items = <(IconData, String, VoidCallback)>[
      (Icons.receipt_long_rounded, 'main_storedashboard_quick_action_orders', () => context.go(Routes.orders)),
      (Icons.add_box_rounded, 'main_storedashboard_quick_action_add_product', () => context.push(Routes.productAdd)),
      (Icons.inventory_2_rounded, 'main_storedashboard_quick_action_manage_stock', () => context.push(Routes.manageStock)),
      (Icons.insights_rounded, 'main_storedashboard_quick_action_analytics', () => context.push(Routes.analytics)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.str('main_storedashboard_quick_actions_title'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 12),
            _TileGrid(
              children: [
                for (final (icon, key, onTap) in items)
                  Material(
                    color: tk.sunken,
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _IconBox(icon),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.str(key),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text1, height: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.s, required this.currency});

  final BusinessSummary s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final rows = <(IconData, String, String)>[
      (Icons.inventory_2_rounded, 'main_storedashboard_products_count_title', s.products.isEmpty ? '—' : s.products),
      (Icons.receipt_long_rounded, 'main_storedashboard_totalOrders', s.orders.isEmpty ? '—' : s.orders),
      (Icons.payments_rounded, 'main_storedashboard_order_amount_title', money(currency, s.orderAmount)),
      (Icons.account_balance_wallet_rounded, 'main_storedashboard_merchant_earnings_title', money(currency, s.merchantEarning)),
      (Icons.storefront_rounded, 'main_storedashboard_store_earnings_title', money(currency, s.storeEarning)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.str('main_storedashboard_business_summary_title'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 12),
            _TileGrid(
              children: [
                for (final (icon, key, value) in rows)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBox(icon),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1, letterSpacing: -0.3)),
                        ),
                        const SizedBox(height: 2),
                        Text(context.str(key), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: tk.text3),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
          ],
        ),
      ),
    );
  }
}

/// 2 tiles per row. With an odd count, the last tile takes the full width.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 10.0;
      final half = (box.maxWidth - gap) / 2;
      final odd = children.length.isOdd;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(width: (odd && i == children.length - 1) ? box.maxWidth : half, child: children[i]),
        ],
      );
    },
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 20, color: context.primary),
  );
}