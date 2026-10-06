import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/app_config.dart';
import '../logic/config_controller.dart';
import 'brand_widgets.dart';
import 'language_sheet.dart';

/// Phone: a full brand-colour screen with the actions at the bottom.
/// Tablet / desktop: split screen. Brand panel on one side, the actions on the other.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider) ?? const AppConfig();
    return context.screen.isWide ? _Split(cfg: cfg) : _Compact(cfg: cfg);
  }
}

// ── shared pieces ───────────────────────────────────────────────────────────

void _login(BuildContext c) => c.push(Routes.login);
void _signup(BuildContext c) => c.push(Routes.signup);

class _LangChip extends ConsumerWidget {
  const _LangChip({required this.cfg, required this.onBrand});

  final AppConfig cfg;
  final bool onBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(stringsProvider.select((s) => s.code));
    final label = cfg.languageName(code) ?? code.toUpperCase();
    final fg = onBrand ? onColor(context.primary) : context.tk.text2;
    final canPick = cfg.supportedLanguages.length > 1;
    return Material(
      color: onBrand ? fg.withValues(alpha: 0.14) : context.tk.sunken,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: canPick ? () => showLanguageSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              if (canPick) Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview flavor only: forget the PIN and go back to the PIN screen.
class _PreviewExit extends ConsumerWidget {
  const _PreviewExit({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppEnv.isPreview) return const SizedBox.shrink();
    return IconButton(
      onPressed: () async {
        await ref.read(appPrefsProvider).setEnteredPin('');
        if (context.mounted) context.go(Routes.previewLogin);
      },
      icon: Icon(Icons.logout_rounded, color: color),
    );
  }
}

class _CmsLinks extends StatelessWidget {
  const _CmsLinks({required this.pages, required this.color});

  final List<CmsPage> pages;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        for (final p in pages)
          TextButton(
            onPressed: () => context.push(Routes.cms(p.slug)),
            style: TextButton.styleFrom(foregroundColor: color, textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            child: Text(p.title),
          ),
      ],
    );
  }
}

// ── phone ───────────────────────────────────────────────────────────────────

class _Compact extends StatelessWidget {
  const _Compact({required this.cfg});

  final AppConfig cfg;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);

    return Scaffold(
      backgroundColor: brand,
      body: BrandBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrandLogo(size: 40, logoUrl: cfg.logoUrl),
                    const Spacer(),
                    _PreviewExit(color: on),
                    _LangChip(cfg: cfg, onBrand: true),
                  ],
                ),
                const Spacer(),
                Text(
                  context.str('auth_welcomeview_maintenance_retailManagementPlatform'),
                  style: TextStyle(color: on, fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
                ),
                const SizedBox(height: 12),
                Text(context.str('auth_welcomeview_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15, height: 1.4)),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => _login(context),
                  style: FilledButton.styleFrom(backgroundColor: on, foregroundColor: brand),
                  child: Text(context.str('auth_welcomeview_login_button')),
                ),
                if (cfg.signupEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _signup(context),
                    style: OutlinedButton.styleFrom(foregroundColor: on, side: BorderSide(color: on.withValues(alpha: 0.7))),
                    child: Text(context.str('auth_welcomeview_sign_up_button')),
                  ),
                ],
                const SizedBox(height: 8),
                _CmsLinks(pages: cfg.cmsPages, color: on.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── tablet / desktop ────────────────────────────────────────────────────────

class _Split extends StatelessWidget {
  const _Split({required this.cfg});

  final AppConfig cfg;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);
    final tk = context.tk;

    Widget feature(IconData icon, String key) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: on.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(context.str(key), style: TextStyle(color: on.withValues(alpha: 0.9), fontSize: 13.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: tk.surface,
      body: Row(
        children: [
          // brand side
          Expanded(
            flex: 11,
            child: ColoredBox(
              color: brand,
              child: BrandBackdrop(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BrandLogo(size: 44, logoUrl: cfg.logoUrl),
                            const SizedBox(width: 14),
                            Flexible(child: Text(AppEnv.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.w700))),
                          ],
                        ),
                        const Spacer(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Text(
                            context.str('auth_welcomeview_maintenance_retailManagementPlatform'),
                            style: TextStyle(color: on, fontSize: 44, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1.2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(context.str('auth_welcomeview_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 17, height: 1.45)),
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          runSpacing: 10,
                          children: [
                            feature(Icons.insights_rounded, 'auth_welcomeview_feature_analytics_title'),
                            feature(Icons.inventory_2_rounded, 'auth_welcomeview_feature_inventory_title'),
                            feature(Icons.groups_rounded, 'auth_welcomeview_feature_team_title'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // action side
          Expanded(
            flex: 9,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Row(children: [const Spacer(), _PreviewExit(color: tk.text2), _LangChip(cfg: cfg, onBrand: false)]),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(context.str('auth_loginscreen_welcomeBack'),
                                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: tk.text1)),
                              const SizedBox(height: 8),
                              Text(context.str('auth_loginscreen_subtitle'), style: TextStyle(fontSize: 15, color: tk.text2)),
                              const SizedBox(height: 28),
                              FilledButton(onPressed: () => _login(context), child: Text(context.str('auth_welcomeview_login_button'))),
                              if (cfg.signupEnabled) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(onPressed: () => _signup(context), child: Text(context.str('auth_welcomeview_sign_up_button'))),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _CmsLinks(pages: cfg.cmsPages, color: tk.text2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}