// The app frame. Phone: bottom bar. Tablet: icon rail. Wide: sidebar + top bar.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../strings/strings_scope.dart';
import 'breakpoints.dart';
import 'design_tokens.dart';
import 'nav_destinations.dart';
import 'shell_data.dart';
import 'theme_controller.dart';

const _kSidebarWidth = 264.0;
const _kSidebarWidthLarge = 288.0;
const _kRailWidth = 84.0;

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.location, required this.child});

  /// GoRouterState.uri.path of the current route.
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = context.screen;
    final tk = context.tk;
    final current = NavDests.forLocation(location);

    if (size.isCompact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: child,
        bottomNavigationBar: NavDests.isTabRoot(location) ? _BottomBar(current: current) : null,
      );
    }

    return Scaffold(
      backgroundColor: tk.canvas,
      body: Row(
        children: [
          if (size.hasSidebar) _Sidebar(current: current, wide: size == ScreenSize.large) else _Rail(current: current),
          Expanded(
            child: Column(
              children: [
                _TopBar(showBrand: !size.hasSidebar),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.header, this.size = 34});

  final ShellHeader header;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = context.primary;
    final initials = Text(
      header.initials,
      style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: size * 0.38),
    );
    final url = header.imageUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: (url == null || url.isEmpty)
          ? initials
          : CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        errorWidget: (_, _, _) => initials,
      ),
    );
  }
}

// ── phone: bottom bar ───────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current});

  final NavDest? current;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final tabs = NavDests.tabs;
    final index = tabs.indexWhere((d) => d == current).clamp(0, tabs.length - 1);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border))),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: tk.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 66,
          indicatorColor: context.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith(
                (s) => TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? context.primary : tk.text2,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(tabs[i].route),
          destinations: [
            for (final d in tabs)
              NavigationDestination(
                icon: Icon(d.icon, color: tk.text2),
                selectedIcon: Icon(d.selectedIcon, color: context.primary),
                label: d == tabs.last ? context.str('main_tabbar_more_label') : context.str(d.labelKey),
              ),
          ],
        ),
      ),
    );
  }
}

// ── tablet: icon rail ───────────────────────────────────────────────────────

class _Rail extends ConsumerWidget {
  const _Rail({required this.current});

  final NavDest? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final primary = context.primary;
    final header = ref.watch(shellHeaderProvider);
    final tabs = NavDests.tabs;

    return Container(
      width: _kRailWidth,
      decoration: BoxDecoration(color: tk.surface,border: BorderDirectional(end: BorderSide(color: tk.border))),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _Avatar(header: header, size: 40),
            const SizedBox(height: 20),
            for (final d in tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Tooltip(
                  message: context.str(d.labelKey),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap: () => context.go(d.route),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: d == current ? primary.withValues(alpha: 0.12) : null,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Column(
                        children: [
                          Icon(d == current ? d.selectedIcon : d.icon, size: 22, color: d == current ? primary : tk.text2),
                          const SizedBox(height: 4),
                          Text(
                            d == tabs.last ? context.str('main_tabbar_more_label') : context.str(d.labelKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: d == current ? FontWeight.w700 : FontWeight.w500,
                              color: d == current ? primary : tk.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── wide: sidebar ───────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.current, required this.wide});

  final NavDest? current;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final isFood = ref.watch(isFoodStoreProvider);
    final header = ref.watch(shellHeaderProvider);

    List<Widget> group(NavGroup g, String? titleKey) {
      final items = NavDests.all.where((d) => d.group == g && (!d.foodOnly || isFood)).toList();
      if (items.isEmpty) return const [];
      return [
        if (titleKey != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
            child: Text(
              context.str(titleKey).toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3),
            ),
          ),
        for (final d in items) _SideTile(dest: d, selected: d == current),
      ];
    }

    return Container(
      width: wide ? _kSidebarWidthLarge : _kSidebarWidth,
      decoration: BoxDecoration(color: tk.surface, border: BorderDirectional(end: BorderSide(color: tk.border))),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(
                children: [
                  _Avatar(header: header, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      header.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ...group(NavGroup.main, null),
                  ...group(NavGroup.finance, 'settings_settings_section_financial_customer'),
                  ...group(NavGroup.store, 'settings_settings_section_store_settings'),
                ],
              ),
            ),
            Divider(color: tk.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(children: group(NavGroup.footer, null)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({required this.dest, required this.selected});

  final NavDest dest;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () => context.go(dest.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(selected ? dest.selectedIcon : dest.icon, size: 20, color: selected ? primary : tk.text2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.str(dest.labelKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? primary : tk.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── wide: top bar (store status, theme, profile) ────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.showBrand});

  final bool showBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final header = ref.watch(shellHeaderProvider);
    final toggle = ref.watch(storeStatusToggleProvider);
    final open = header.isOpen;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: tk.surface, border: Border(bottom: BorderSide(color: tk.border))),
      child: Row(
        children: [
          if (showBrand)
            Expanded(
              child: Text(
                header.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text1),
              ),
            )
          else
            const Spacer(),

          if (open != null && toggle != null) ...[
            Container(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
              decoration: BoxDecoration(color: open ? tk.successBg : tk.dangerBg, borderRadius: BorderRadius.circular(50)),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: open ? tk.success : tk.danger),
                  const SizedBox(width: 8),
                  Text(
                    open ? context.str('storedetails_storetimeslots_open') : context.str('storedetails_storetimeslots_closed'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: open ? tk.success : tk.danger),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 52,
                    height: 36,
                    child: Center(
                      child: header.updating
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.primary))
                          : Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: open,
                          onChanged: (on) async {
                            final err = await toggle(on);
                            if (err != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          const ThemeToggleButton(),
          const SizedBox(width: 4),

          PopupMenuButton<String>(
            tooltip: context.str('settings_settings_row_store_profile_title'),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
            onSelected: (route) => context.go(route),
            itemBuilder: (_) => [
              PopupMenuItem(value: Routes.storeProfile, child: Text(context.str('settings_settings_row_store_profile_title'))),
              PopupMenuItem(value: Routes.more, child: Text(context.str('settings_settings_title'))),
            ],
            child: _Avatar(header: header, size: 36),
          ),
        ],
      ),
    );
  }
}