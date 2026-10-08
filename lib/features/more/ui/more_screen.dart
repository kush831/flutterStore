import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_controller.dart'; // ← the file where themeModeProvider is declared (grep -rn "themeModeProvider =" lib)
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/app_language.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../push/logic/push_service.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/language_sheet.dart';
import '../../store/logic/store_providers.dart';
import '../data/account_repository.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _busy = false; // a logout or a deletion is running: the page is locked

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.logout_rounded, size: 36, color: ctx.primary),
        title: Text(ctx.str('auth_loginscreen_merchant_logout_title')),
        content: Text(ctx.str('auth_loginscreen_merchant_logout_message'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(ctx.str('settings_settings_row_yesLogOut'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await ref.read(accountRepositoryProvider).logout(); // never throws
    await ref.read(authControllerProvider.notifier).signOut(); // the router takes it from here
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever_rounded, size: 40, color: ctx.tk.danger),
        title: Text(ctx.str('storedetails_storeprofile_delete_account_title')),
        content: Text(ctx.str('storedetails_storeprofile_delete_account_message'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)),
            child: Text(ctx.str('storedetails_storeprofile_delete_account_confirm_button')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      if (!mounted) return;
      await ref.read(authControllerProvider.notifier).signOut(); // deleted: nothing left to stay signed in to
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true); // the server refused: stay signed in
    }
  }

  // ── pieces ──

  Widget _tile(BuildContext context, {required IconData icon, required String titleKey, String? subtitleKey, VoidCallback? onTap, Widget? trailing, bool danger = false}) {
    final tk = context.tk;
    final c = danger ? tk.danger : context.primary;
    return ListTile(
      enabled: !_busy,
      onTap: onTap,
      leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: c)),
      title: Text(context.str(titleKey), style: TextStyle(fontWeight: FontWeight.w600, color: danger ? tk.danger : tk.text1)),
      subtitle: subtitleKey == null ? null : Text(context.str(subtitleKey), style: TextStyle(fontSize: 12.5, color: tk.text2)),
      trailing: trailing ?? (onTap != null && !danger ? Icon(Icons.chevron_right_rounded, color: tk.text3) : null),
    );
  }

  Widget _group(BuildContext context, String? titleKey, List<Widget> tiles) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleKey != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(context.str(titleKey).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)),
          ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) Divider(height: 1, color: tk.border), tiles[i]]]),
        ),
      ],
    );
  }

  Widget _themeTile(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      children: [
        _tile(context, icon: Icons.palette_outlined, titleKey: 'settings_settings_row_change_theme_title', subtitleKey: 'settings_settings_toggle_theme_message'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded, size: 18), label: Text(context.str('themeselector_styleguide_appearance_system'))),
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined, size: 18), label: Text(context.str('themeselector_styleguide_appearance_light'))),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined, size: 18), label: Text(context.str('themeselector_styleguide_appearance_dark'))),
              ],
              selected: {mode},
              onSelectionChanged: _busy ? null : (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final home = ref.watch(dashboardProvider.select((s) => s.home.value));
    final isFood = ref.watch(appPrefsProvider).isFood;
    final availability = ref.watch(storeProfileProvider.select((a) => a.value?.availabilityEnabled ?? false));
    final langCode = ref.watch(stringsProvider.select((s) => s.code));
    final languages = ref.watch(appConfigProvider)?.languages ?? const [];
    final langName = languages.where((l) => l.locale == langCode).firstOrNull?.name ?? langCode.toUpperCase();
    final version = ref.watch(appVersionProvider).value;
    final title = context.str('settings_settings_title');

    // ── the store card ──
    final name = home?.storeName ?? '';
    final logoFallback = Container(color: context.primary.withValues(alpha: 0.12), alignment: Alignment.center, child: Text(name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary)));
    final storeCard = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : () => context.push(Routes.storeProfile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: (home?.profileImage ?? '').isEmpty ? logoFallback : CachedNetworkImage(imageUrl: home!.profileImage, fit: BoxFit.cover, memCacheWidth: 170, placeholder: (_, _) => logoFallback, errorWidget: (_, _, _) => logoFallback),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
                Text(context.str('settings_settings_row_ownerAccount'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: tk.text3),
          ]),
        ),
      ),
    );

    // ── the groups ──
    final storeSettings = _group(context, 'settings_settings_section_store_settings', [
      _tile(context, icon: Icons.storefront_outlined, titleKey: 'settings_settings_row_store_profile_title', subtitleKey: 'settings_settings_row_store_profile_message', onTap: () => context.push(Routes.storeProfile)),
      _tile(context, icon: Icons.schedule_rounded, titleKey: 'settings_settings_row_store_timings_title', subtitleKey: 'settings_settings_row_store_timings_message', onTap: () => context.push(Routes.timings)),
      _tile(context, icon: Icons.category_outlined, titleKey: 'settings_settings_row_categories_title', subtitleKey: 'settings_settings_row_categories_message', onTap: () => context.push(Routes.categories)),
      if (isFood) _tile(context, icon: Icons.tune_rounded, titleKey: 'settings_settings_row_options', subtitleKey: 'settings_settings_row_optionsDesc', onTap: () => context.push(Routes.options)),
      if (availability) _tile(context, icon: Icons.event_available_rounded, titleKey: 'storedetails_storeprofile_screen_productAvailability', subtitleKey: 'storedetails_storeprofile_screen_setTimeSlabsForAvailability', onTap: () => context.push(Routes.timeSlabs)),
    ]);

    final financial = _group(context, 'settings_settings_section_financial_customer', [
      _tile(context, icon: Icons.payments_outlined, titleKey: 'main_storedashboard_store_earnings_title', subtitleKey: 'settings_settings_row_detailEarningReport', onTap: () => context.push(Routes.earnings)),
      _tile(context, icon: Icons.account_balance_wallet_outlined, titleKey: 'settings_settings_row_walletTransactions', subtitleKey: 'settings_settings_row_viewAllWalletActivity', onTap: () => context.push(Routes.wallet)),
      _tile(context, icon: Icons.request_quote_outlined, titleKey: 'settings_settings_row_cashoutRequest', subtitleKey: 'settings_settings_row_cashoutRequestDesc', onTap: () => context.push(Routes.cashout)),
      _tile(context, icon: Icons.insights_outlined, titleKey: 'storedetails_storeanalytics_title', onTap: () => context.push(Routes.analytics)),
      _tile(context, icon: Icons.workspace_premium_outlined, titleKey: 'settings_settings_row_memberShip', subtitleKey: 'settings_settings_row_memberShipDesc', onTap: () => context.push(Routes.membership)),
      _tile(context, icon: Icons.history_rounded, titleKey: 'settings_settings_row_past_orders_title', onTap: () => context.go(Routes.ordersTab('completed'))),
    ]);

    final preferences = _group(context, 'settings_settings_section_preferences', [
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
      if (ref.watch(pushTransportProvider).supported)
        _tile(
          context,
          icon: Icons.notifications_active_outlined,
          titleKey: 'settings_settings_toggle_notifications_title',
          subtitleKey: 'settings_settings_toggle_notifications_message',
          trailing: Switch(value: ref.watch(pushEnabledProvider), onChanged: _busy ? null : (v) => ref.read(pushEnabledProvider.notifier).set(v)),
        ),
      _themeTile(context),
    ]);

    final account = _group(context, null, [
      _tile(context, icon: Icons.logout_rounded, titleKey: 'settings_settings_logout_title', onTap: _logout, danger: true),
      _tile(context, icon: Icons.delete_outline_rounded, titleKey: 'storedetails_storeprofile_delete_account_title', subtitleKey: 'settings_settings_row_forAccountDelete', onTap: _deleteAccount, danger: true),
    ]);

    const gap = SizedBox(height: 0);
    final left = <Widget>[storeCard, storeSettings, preferences];
    final right = <Widget>[financial, account];

    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final w in items) ...[w, gap]]);

    final footer = version == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 20), child: Center(child: Text('v$version', style: TextStyle(fontSize: 12, color: tk.text3))));

    final content = ListView(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 0, compact ? 8 : 0, compact ? 16 : 0, 32),
      children: [
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: column(left)), const SizedBox(width: 16), Expanded(child: column(right))])
        else ...[storeCard, storeSettings, financial, preferences, const SizedBox(height: 18), account],
        footer,
      ],
    );

    final locked = Stack(children: [
      Positioned.fill(child: AbsorbPointer(absorbing: _busy, child: content)),
      if (_busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
    ]);

    if (compact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1))),
              Expanded(child: locked),
            ],
          ),
        ),
      );
    }
    return AdaptivePage(title: title, child: locked);
  }
}