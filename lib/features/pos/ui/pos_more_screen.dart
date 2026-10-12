import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/language_sheet.dart';
import '../data/pos_permission.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';

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

  Widget _tile(BuildContext context, {required IconData icon, required String titleKey, String? subtitleKey, VoidCallback? onTap, Widget? trailing, bool danger = false}) {
    final tk = context.tk;
    final c = danger ? tk.danger : context.primary;
    return ListTile(
      enabled: !_exiting,
      onTap: onTap,
      leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: c)),
      title: Text(context.str(titleKey), style: TextStyle(fontWeight: FontWeight.w600, color: danger ? tk.danger : tk.text1)),
      subtitle: subtitleKey == null ? null : Text(context.str(subtitleKey), style: TextStyle(fontSize: 12.5, color: tk.text2)),
      trailing: trailing ?? (danger ? null : Icon(Icons.chevron_right_rounded, color: tk.text3)),
    );
  }

  Widget _group(BuildContext context, String? titleKey, List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleKey != null)
          Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(context.str(titleKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) Divider(height: 1, color: tk.border), tiles[i]]]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final auth = ref.watch(posAuthProvider);
    final staff = auth.staff;
    final languages = ref.watch(appConfigProvider)?.languages ?? const [];
    final langCode = ref.watch(stringsProvider.select((s) => s.code));
    final langName = languages.where((l) => l.locale == langCode).firstOrNull?.name ?? langCode.toUpperCase();

    // ── who is signed in ──
    final name = staff?.name ?? '';
    final header = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: context.primary.withValues(alpha: 0.14), child: Text(name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.primary))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
              Text([if ((staff?.roleName ?? '').isNotEmpty) staff!.roleName, if ((staff?.business.name ?? '').isNotEmpty) staff!.business.name].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
            child: Text(context.str('pos_posmorescreen_pos_mode_active'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tk.success)),
          ),
        ]),
      ),
    );

    // ── the menu: every row follows the permissions of the signed-in staff member (Jetpack's rules) ──
    final management = _group(context, 'pos_posmorescreen_section_store_management', [
      if (auth.can(PosPerm.reportsView)) _tile(context, icon: Icons.insights_outlined, titleKey: 'pos_posmorescreen_item_analytics_title', subtitleKey: 'pos_posmorescreen_item_analytics_subtitle', onTap: () => context.push(Routes.posAnalytics)),
      _tile(context, icon: Icons.storefront_outlined, titleKey: 'pos_posmorescreen_item_store_profile_title', subtitleKey: 'pos_posmorescreen_item_store_profile_subtitle', onTap: () => context.push(Routes.posStoreProfile)),
      if (auth.canAny([PosPerm.viewAllSessions, PosPerm.closeSession])) _tile(context, icon: Icons.schedule_rounded, titleKey: 'pos_posmorescreen_item_sessions_title', subtitleKey: 'pos_posmorescreen_item_sessions_subtitle', onTap: () => context.push(Routes.posSessions)),
      if (auth.canAny([PosPerm.terminalManage, PosPerm.terminalView])) _tile(context, icon: Icons.devices_other_outlined, titleKey: 'pos_posmorescreen_item_terminals_title', subtitleKey: 'pos_posmorescreen_item_terminals_subtitle', onTap: () => context.push(Routes.posTerminals)),
    ]);

    final team = _group(context, 'pos_posmorescreen_section_team', [
      if (auth.canAny([PosPerm.staffManage, PosPerm.staffView])) _tile(context, icon: Icons.groups_2_outlined, titleKey: 'pos_posmorescreen_item_staff_title', subtitleKey: 'pos_posmorescreen_item_staff_subtitle', onTap: () => context.push(Routes.posStaff)),
      _tile(
        context,
        icon: Icons.language_rounded,
        titleKey: 'settings_settings_row_change_language_title',
        onTap: () => showLanguageSheet(context),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(50)), child: Text(langName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tk.text2))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: tk.text3),
        ]),
      ),
    ]);

    final exit = _group(context, null, [
      _tile(context, icon: Icons.logout_rounded, titleKey: 'pos_posmorescreen_exit_pos_row', subtitleKey: 'pos_posmorescreen_exit_pos_row_subtitle', onTap: _exit, danger: true),
    ]);

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
                    management,
                    team,
                    const SizedBox(height: 18),
                    exit,
                  ],
                ),
              ),
            ),
          ),
          if (_exiting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(children: [
                const LinearProgressIndicator(minHeight: 3),
                Padding(padding: const EdgeInsets.all(10), child: Text(context.str('pos_posmorescreen_exiting_pos_mode'), style: TextStyle(color: tk.text2))),
              ]),
            ),
        ],
      ),
    );
  }
}