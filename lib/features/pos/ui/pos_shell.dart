import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_exit.dart';
import '../logic/pos_staff_logic.dart';

/// One place in the menu: its route, the pages that belong under it, and who may see it.
class _Dest {
  const _Dest(this.route, this.icon, this.iconOn, this.labelKey, {this.also = const [], this.anyOf = const [], this.exact = false});

  final String route;
  final IconData icon;
  final IconData iconOn;
  final String labelKey;
  final List<String> also;
  final List<String> anyOf; // permissions: any one is enough; empty = everyone
  final bool exact;

  bool matches(String loc) => exact ? loc == route : [route, ...also].any((p) => loc == p || loc.startsWith('$p/'));
}

const _dashboard = _Dest(Routes.pos, Icons.grid_view_outlined, Icons.grid_view_rounded, 'pos_posdashboardscreen_nav_dashboard', exact: true);
const _products = _Dest(Routes.posProducts, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'pos_posdashboardscreen_nav_products', also: [Routes.posCategories, Routes.posCategory, Routes.posSearch, Routes.posScan, Routes.posProduct, Routes.posCart, Routes.posHeldCarts, Routes.posPayment, Routes.posOrderSuccess, Routes.posReceipt]);
const _orders = _Dest(Routes.posOrders, Icons.list_alt_outlined, Icons.list_alt_rounded, 'pos_posdashboardscreen_nav_orders', also: [Routes.posOrderQueue, Routes.posOrder]);
const _sessions = _Dest(Routes.posSessions, Icons.schedule_outlined, Icons.schedule_rounded, 'pos_nav_sessions', also: [Routes.posCloseSession, Routes.posSessionClosed, Routes.posHandover, Routes.posTransfer, Routes.posShiftHistory, Routes.posAllSessions]);
const _terminals = _Dest(Routes.posTerminals, Icons.desktop_windows_outlined, Icons.desktop_windows_rounded, 'pos_nav_terminals');
const _staff = _Dest(Routes.posStaff, Icons.groups_2_outlined, Icons.groups_2_rounded, 'pos_posstaffscreen_staff', also: [Routes.posAllStaff, Routes.posStaffMember, Routes.posStatusHistory, Routes.posRoles], anyOf: ['staff:view', 'staff:manage']);
const _analysis = _Dest(Routes.posAnalytics, Icons.insights_outlined, Icons.insights_rounded, 'pos_posanalysisscreen_top_bar_title', anyOf: ['reports:view']);
const _profile = _Dest(Routes.posStoreProfile, Icons.storefront_outlined, Icons.storefront_rounded, 'pos_nav_store_profile');
const _more = _Dest(Routes.posMore, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'pos_posdashboardscreen_nav_more');
const _all = [_dashboard, _products, _orders, _sessions, _terminals, _staff, _analysis, _profile, _more];
const _phoneTabs = [_dashboard, _products, _orders, _more];

/// Which menu item a page belongs under (the pages are matched by whole path segments, so "/pos/order-success" is not "/pos/order").
String posNavFor(String location) => _all.where((d) => d.matches(location)).firstOrNull?.route ?? Routes.pos;

/// The four pages of the phone's bottom bar. Every other page is pushed on top, without the bar.
bool posIsTabRoot(String location) => _phoneTabs.any((d) => d.route == location);

/// The POS frame. Phone: a bottom bar on the four tabs. Tablet: an icon rail. iPad landscape and browser: the sidebar with names.
class PosShell extends ConsumerWidget {
  const PosShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final size = context.screen;
    final auth = ref.watch(posAuthProvider);
    final selected = posNavFor(location);
    bool allowed(_Dest d) => d.anyOf.isEmpty || d.anyOf.any(auth.can);

    if (size.isCompact) {
      final i = _phoneTabs.indexWhere((d) => d.route == selected);
      return Scaffold(
        backgroundColor: tk.canvas,
        body: child,
        bottomNavigationBar: posIsTabRoot(location)
            ? NavigationBar(
          selectedIndex: i < 0 ? 0 : i,
          onDestinationSelected: (x) => context.go(_phoneTabs[x].route),
          destinations: [for (final d in _phoneTabs) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.iconOn), label: context.str(d.labelKey))],
        )
            : null,
      );
    }

    final staff = auth.staff;
    final storeName = staff?.business.name ?? '';
    final terminal = ref.watch(posActiveSessionProvider).value?.terminalName ?? '';
    void exit() => posExit(context, ref);

    return Scaffold(
      backgroundColor: tk.canvas,
      body: Row(children: [
        size.hasSidebar
            ? _Sidebar(selected: selected, allowed: allowed, storeName: storeName, terminal: terminal, onExit: exit)
            : _Rail(selected: selected, allowed: allowed, onExit: exit),
        VerticalDivider(width: 1, color: tk.border),
        Expanded(
          child: Column(children: [
            _TopBar(name: staff?.name ?? ''),
            Expanded(child: child),
          ]),
        ),
      ]),
    );
  }
}

// ── sidebar (1024 px and wider) ───────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.allowed, required this.storeName, required this.terminal, required this.onExit});

  final String selected;
  final bool Function(_Dest) allowed;
  final String storeName;
  final String terminal;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget item(_Dest d) => allowed(d) ? _SideItem(icon: d.route == selected ? d.iconOn : d.icon, label: context.str(d.labelKey), on: d.route == selected, onTap: () => context.go(d.route)) : const SizedBox.shrink();
    Widget section(String key) => Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 4), child: Text(context.str(key), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

    return Container(
      width: 264,
      color: tk.surface,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              CircleAvatar(radius: 20, backgroundColor: context.primary.withValues(alpha: 0.14), child: Text(initialsOf(storeName), style: TextStyle(fontWeight: FontWeight.w800, color: context.primary))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                  Text(['POS', if (terminal.isNotEmpty) terminal].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: tk.text3)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), children: [
              item(_dashboard),
              item(_products),
              item(_orders),
              section('pos_nav_shift'),
              item(_sessions),
              item(_terminals),
              section('pos_nav_team_reports'),
              item(_staff),
              item(_analysis),
              item(_profile),
            ]),
          ),
          Divider(height: 1, color: tk.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: Column(children: [
              item(_more),
              _SideItem(icon: Icons.logout_rounded, label: context.str('pos_nav_exit'), on: false, danger: true, onTap: onExit),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.icon, required this.label, required this.on, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final bool on;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = danger ? tk.danger : (on ? context.primary : tk.text2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: on ? context.primary.withValues(alpha: 0.12) : null, borderRadius: BorderRadius.circular(Radii.md)),
          child: Row(children: [Icon(icon, size: 21, color: c), const SizedBox(width: 12), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: c)))]),
        ),
      ),
    );
  }
}

// ── icon rail (600 to 1023 px) ────────────────────────────────────────────────

class _Rail extends StatelessWidget {
  const _Rail({required this.selected, required this.allowed, required this.onExit});

  final String selected;
  final bool Function(_Dest) allowed;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget item(IconData icon, String label, bool on, VoidCallback onTap, {bool danger = false}) {
      final c = danger ? tk.danger : (on ? context.primary : tk.text2);
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: on ? context.primary.withValues(alpha: 0.12) : null, borderRadius: BorderRadius.circular(Radii.md)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 22, color: c), const SizedBox(height: 3), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: c))]),
          ),
        ),
      );
    }

    return Container(
      width: 84,
      color: tk.surface,
      child: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Icon(Icons.point_of_sale_rounded, color: context.primary)),
          Expanded(
            child: ListView(children: [
              for (final d in _all)
                if (allowed(d)) item(d.route == selected ? d.iconOn : d.icon, context.str(d.labelKey), d.route == selected, () => context.go(d.route)),
            ]),
          ),
          item(Icons.logout_rounded, context.str('pos_nav_exit'), false, onExit, danger: true),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── top bar (tablet and wider) ────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: tk.surface, border: Border(bottom: BorderSide(color: tk.border))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (name.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 10), child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text2))),
        CircleAvatar(radius: 16, backgroundColor: context.primary.withValues(alpha: 0.14), child: Text(initialsOf(name), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.primary))),
      ]),
    );
  }
}