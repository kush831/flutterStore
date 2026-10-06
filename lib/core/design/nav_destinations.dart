import 'package:flutter/material.dart';

import '../router/routes.dart';

enum NavGroup { main, finance, store, footer }

class NavDest {
  const NavDest({
    required this.route,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
    required this.group,
    this.tab = false,
    this.foodOnly = false,
  });

  final String route;
  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
  final NavGroup group;

  /// One of the 4 phone / tablet tabs.
  final bool tab;
  final bool foodOnly;

  /// The page itself or any page under its prefix.
  bool contains(String location) => location == route || location.startsWith('$route/');
}

abstract final class NavDests {
  static const all = <NavDest>[
    NavDest(
      route: Routes.home,
      labelKey: 'main_tabbar_home_label',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      group: NavGroup.main,
      tab: true,
    ),
    NavDest(
      route: Routes.orders,
      labelKey: 'main_tabbar_orders_label',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      group: NavGroup.main,
      tab: true,
    ),
    NavDest(
      route: Routes.products,
      labelKey: 'main_tabbar_products_label',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      group: NavGroup.main,
      tab: true,
    ),
    NavDest(
      route: Routes.analytics,
      labelKey: 'storedetails_storeanalytics_title',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      group: NavGroup.main,
    ),
    NavDest(
      route: Routes.earnings,
      labelKey: 'storedetails_storeanalytics_store_earnings_title',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      group: NavGroup.finance,
    ),
    NavDest(
      route: Routes.wallet,
      labelKey: 'settings_settings_row_walletTransactions',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      group: NavGroup.finance,
    ),
    NavDest(
      route: Routes.cashout,
      labelKey: 'settings_settings_row_cashoutRequest',
      icon: Icons.request_quote_outlined,
      selectedIcon: Icons.request_quote_rounded,
      group: NavGroup.finance,
    ),
    NavDest(
      route: Routes.categories,
      labelKey: 'settings_settings_row_categories_title',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      group: NavGroup.store,
    ),
    NavDest(
      route: Routes.options,
      labelKey: 'settings_settings_row_options',
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      group: NavGroup.store,
      foodOnly: true,
    ),
    NavDest(
      route: Routes.storeProfile,
      labelKey: 'settings_settings_row_store_profile_title',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      group: NavGroup.store,
    ),
    NavDest(
      route: Routes.timings,
      labelKey: 'settings_settings_row_store_timings_title',
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule_rounded,
      group: NavGroup.store,
    ),
    NavDest(
      route: Routes.more,
      labelKey: 'settings_settings_title',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      group: NavGroup.footer,
      tab: true,
    ),
  ];

  static List<NavDest> get tabs => all.where((d) => d.tab).toList();

  static NavDest? forLocation(String location) {
    for (final d in all) {
      if (d.contains(location)) return d;
    }
    return null;
  }

  /// The bottom bar shows only on the 4 tab pages themselves, not on details and editors.
  static bool isTabRoot(String location) => tabs.any((d) => d.route == location);
}