import 'package:apporio_store_30sept/features/pos/ui/pos_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/language_sheet.dart';
import '../data/pos_permission.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';

/// One row of the menu. The same list is drawn as a grouped list on a phone and as tiles on a tablet and a browser.
class _Item {
  const _Item({required this.icon, required this.titleKey, this.subtitleKey, this.onTap, this.trailing, this.danger = false});

  final IconData icon;
  final String titleKey;
  final String? subtitleKey;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
}

class PosMoreScreen extends ConsumerStatefulWidget {
  const PosMoreScreen({super.key});

  @override
  ConsumerState<PosMoreScreen> createState() => _PosMoreScreenState();
}

class _PosMoreScreenState extends ConsumerState<PosMoreScreen> {
  bool _exiting = false;

  Future<void> _exit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.logout_rounded, size: 36, color: ctx.tk.danger),
        title: Text(ctx.str('pos_posmorescreen_exit_pos_mode_title')),
        content: Text(ctx.str('pos_posmorescreen_exit_pos_mode_message'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posmorescreen_exit_button'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _exiting = true);
    final staff = ref.read(posAuthProvider).staff;
    await ref.read(posRepositoryProvider).logout(staff?.business.id ?? ''); // never throws
    final auth = ref.read(posAuthProvider.notifier);
    final target = ref.read(authControllerProvider).loggedIn ? Routes.more : Routes.welcome; // the owner goes back to Settings
    if (!mounted) return;
    context.go(target); // first leave the POS pages, then clear the session (no flash of the POS login)
    await auth.signOut();
  }

  // ── phone: the grouped list ────────────────────────────────────────────────
  Widget _listTile(BuildContext context, _Item i) {
    final tk = context.tk;
    final c = i.danger ? tk.danger : context.primary;
    return ListTile(
      enabled: !_exiting,
      onTap: i.onTap,
      leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(i.icon, size: 20, color: c)),
      title: Text(context.str(i.titleKey), style: TextStyle(fontWeight: FontWeight.w600, color: i.danger ? tk.danger : tk.text1)),
      subtitle: i.subtitleKey == null ? null : Text(context.str(i.subtitleKey!), style: TextStyle(fontSize: 12.5, color: tk.text2)),
      trailing: i.trailing ?? (i.danger ? null : Icon(Icons.chevron_right_rounded, color: tk.text3)),
    );
  }

  Widget _group(BuildContext context, String? titleKey, List<_Item> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tk = context.tk;
    final tiles = [for (final i in items) _listTile(context, i)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleKey != null) Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(context.str(titleKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) Divider(height: 1, color: tk.border), tiles[i]]]),
        ),
      ],
    );
  }

  // ── tablet and browser: tiles in a grid ────────────────────────────────────
  Widget _tileCard(BuildContext context, _Item i) {
    final tk = context.tk;
    final c = i.danger ? tk.danger : context.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _exiting ? null : i.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(i.icon, size: 21, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.str(i.titleKey), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                if (i.subtitleKey != null) Text(context.str(i.subtitleKey!), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.3)),
              ]),
            ),
            i.trailing ?? Icon(Icons.chevron_right_rounded, color: tk.text3),
          ]),
        ),
      ),
    );
  }

  Widget _tileGroup(BuildContext context, String titleKey, List<_Item> items, int cols) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tk = context.tk;
    final rows = (items.length / cols).ceil();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(context.str(titleKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PosEqualRow(children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 10),
                Expanded(child: r * cols + c < items.length ? _tileCard(context, items[r * cols + c]) : const SizedBox.shrink()),
              ],
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final auth = ref.watch(posAuthProvider);
    final staff = auth.staff;
    final languages = ref.watch(appConfigProvider)?.languages ?? const [];
    final langCode = ref.watch(stringsProvider.select((s) => s.code));
    final langName = languages.where((l) => l.locale == langCode).firstOrNull?.name ?? langCode.toUpperCase();

    // ── who is signed in ──
    final name = staff?.name ?? '';
    final subline = [if ((staff?.roleName ?? '').isNotEmpty) staff!.roleName, if ((staff?.business.name ?? '').isNotEmpty) staff!.business.name].join('  ·  ');
    final activeChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Text(context.str('pos_posmorescreen_pos_mode_active'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tk.success)),
    );
    final initial = name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase();

    final header = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: context.primary.withValues(alpha: 0.14), child: Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.primary))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
              Text(subline, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
            ]),
          ),
          activeChip,
        ]),
      ),
    );

    // a taller card for the tablet and the browser: the avatar over the name
    final profileCard = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          CircleAvatar(radius: 34, backgroundColor: context.primary.withValues(alpha: 0.14), child: Text(initial, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.primary))),
          const SizedBox(height: 10),
          Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 2),
          Text(subline, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: tk.text2)),
          const SizedBox(height: 10),
          activeChip,
        ]),
      ),
    );

    // ── the menu: every row follows the permissions of the signed-in staff member (Jetpack's rules) ──
    final management = <_Item>[
      if (auth.can(PosPerm.reportsView)) _Item(icon: Icons.insights_outlined, titleKey: 'pos_posmorescreen_item_analytics_title', subtitleKey: 'pos_posmorescreen_item_analytics_subtitle', onTap: () => context.go(Routes.posAnalytics)),
      _Item(icon: Icons.storefront_outlined, titleKey: 'pos_posmorescreen_item_store_profile_title', subtitleKey: 'pos_posmorescreen_item_store_profile_subtitle', onTap: () => context.go(Routes.posStoreProfile)),
      if (auth.canAny([PosPerm.viewAllSessions, PosPerm.closeSession])) _Item(icon: Icons.schedule_rounded, titleKey: 'pos_posmorescreen_item_sessions_title', subtitleKey: 'pos_posmorescreen_item_sessions_subtitle', onTap: () => context.go(Routes.posSessions)),
      if (auth.canAny([PosPerm.terminalManage, PosPerm.terminalView])) _Item(icon: Icons.devices_other_outlined, titleKey: 'pos_posmorescreen_item_terminals_title', subtitleKey: 'pos_posmorescreen_item_terminals_subtitle', onTap: () => context.go(Routes.posTerminals)),
    ];

    final languagePill = Row(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(50)), child: Text(langName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tk.text2))),
      const SizedBox(width: 4),
      Icon(Icons.chevron_right_rounded, color: tk.text3),
    ]);

    final team = <_Item>[
      if (auth.canAny([PosPerm.staffManage, PosPerm.staffView])) _Item(icon: Icons.groups_2_outlined, titleKey: 'pos_posmorescreen_item_staff_title', subtitleKey: 'pos_posmorescreen_item_staff_subtitle', onTap: () => context.go(Routes.posStaff)),
      _Item(icon: Icons.language_rounded, titleKey: 'settings_settings_row_change_language_title', onTap: () => showLanguageSheet(context), trailing: languagePill),
    ];

    final exitItem = _Item(icon: Icons.logout_rounded, titleKey: 'pos_posmorescreen_exit_pos_row', subtitleKey: 'pos_posmorescreen_exit_pos_row_subtitle', onTap: _exit, danger: true);

    final exitingBar = !_exiting
        ? const SizedBox.shrink()
        : Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(children: [
        const LinearProgressIndicator(minHeight: 3),
        Padding(padding: const EdgeInsets.all(10), child: Text(context.str('pos_posmorescreen_exiting_pos_mode'), style: TextStyle(color: tk.text2))),
      ]),
    );

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      return SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _exiting,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: 14, left: 4), child: Text(context.str('pos_posmorescreen_screen_title'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1))),
                      header,
                      _group(context, 'pos_posmorescreen_section_store_management', management),
                      _group(context, 'pos_posmorescreen_section_team', team),
                      const SizedBox(height: 18),
                      _group(context, null, [exitItem]),
                    ],
                  ),
                ),
              ),
            ),
            exitingBar,
          ],
        ),
      );
    }

    // ══ tablet and browser: the store app's page header, the profile on the left, the tiles on the right ══
    final body = LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 700;
      final cols = (two ? box.maxWidth * 0.62 : box.maxWidth) >= 460 ? 2 : 1;
      final exitButton = OutlinedButton.icon(
        onPressed: _exiting ? null : _exit,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), foregroundColor: tk.danger, side: BorderSide(color: tk.danger)),
        icon: const Icon(Icons.logout_rounded),
        label: Text(context.str('pos_posmorescreen_exit_pos_row')),
      );
      final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [profileCard, const SizedBox(height: 14), exitButton]);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tileGroup(context, 'pos_posmorescreen_section_store_management', management, cols),
        _tileGroup(context, 'pos_posmorescreen_section_team', team, cols),
      ]);
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: two
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 4, child: left), const SizedBox(width: 24), Expanded(flex: 7, child: right)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 20), right]),
      );
    });

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _exiting,
          child: AdaptivePage(title: context.str('pos_posmorescreen_screen_title'), subtitle: context.str('pos_posmorescreen_subtitle'), child: body),
        ),
        exitingBar,
      ],
    );
  }
}