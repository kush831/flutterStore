import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';

/// The POS frame: Dashboard · Products · Orders · More. A bottom bar on a phone, a side rail on wide screens.
class PosShell extends StatelessWidget {
  const PosShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = <(String, IconData, IconData, String)>[
    (Routes.pos, Icons.grid_view_outlined, Icons.grid_view_rounded, 'pos_posdashboardscreen_nav_dashboard'),
    (Routes.posProducts, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'pos_posdashboardscreen_nav_products'),
    (Routes.posOrders, Icons.list_alt_outlined, Icons.list_alt_rounded, 'pos_posdashboardscreen_nav_orders'),
    (Routes.posMore, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'pos_posdashboardscreen_nav_more'),
  ];

  int get _index {
    final i = _tabs.indexWhere((t) => t.$1 == location);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final width = MediaQuery.sizeOf(context).width;
    void go(int i) => context.go(_tabs[i].$1);

    if (width >= 760) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1100,
              selectedIndex: _index,
              onDestinationSelected: go,
              leading: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Icon(Icons.point_of_sale_rounded, color: context.primary)),
              destinations: [for (final t in _tabs) NavigationRailDestination(icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: Text(context.str(t.$4)))],
            ),
            VerticalDivider(width: 1, color: tk.border),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: tk.canvas,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: [for (final t in _tabs) NavigationDestination(icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: context.str(t.$4))],
      ),
    );
  }
}