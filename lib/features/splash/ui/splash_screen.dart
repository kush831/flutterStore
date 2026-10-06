import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/config_controller.dart';
import '../logic/splash_controller.dart';
import '../logic/store_links.dart';
import 'brand_widgets.dart';
import 'consent_sheet.dart';
import 'language_sheet.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  void _onChange(SplashState? prev, SplashState next) {
    if (prev?.phase == next.phase) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctrl = ref.read(splashControllerProvider.notifier);
      switch (next.phase) {
        case SplashPhase.consent:
          await showConsentSheet(context);
          if (mounted) await ctrl.consentGiven();
        case SplashPhase.language:
          await showLanguageSheet(context, dismissible: false);
          if (mounted) await ctrl.languagePicked();
        case SplashPhase.done:
          context.go(next.route!);
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(splashControllerProvider);
    ref.listen<SplashState>(splashControllerProvider, _onChange);
    final brand = context.primary;
    final on = onColor(brand);
    final ctrl = ref.read(splashControllerProvider.notifier);
    final logo = ref.watch(appConfigProvider)?.logoUrl ?? '';

    final Widget view = switch (st.phase) {
      SplashPhase.maintenance => _MessageCard(
        icon: Icons.construction_rounded,
        title: context.str('auth_welcomeview_maintenance_appUnderMaintenance'),
        message: st.message,
        primary: FilledButton(onPressed: ctrl.start, child: Text(context.str('common_allscreen_try_again'))),
        secondary: defaultTargetPlatform == TargetPlatform.android && !kIsWeb
            ? TextButton(onPressed: SystemNavigator.pop, child: Text(context.str('auth_welcomeview_maintenance_exitApp')))
            : null,
      ),
      SplashPhase.update => _MessageCard(
        icon: Icons.system_update_rounded,
        badge: st.mandatory ? context.str('auth_welcomeview_maintenance_mandatoryUpdate') : null,
        title: context.str('auth_welcomeview_update_title'),
        message: st.message,
        primary: FilledButton(
          onPressed: () {
            final cfg = ctrl.config;
            if (cfg != null) openStoreListing(cfg.update);
          },
          child: Text(context.str('auth_welcomeview_update_button_title')),
        ),
        secondary: st.mandatory ? null : TextButton(onPressed: ctrl.skipUpdate, child: Text(context.str('auth_welcomeview_update_do_it_later'))),
      ),
      SplashPhase.noData => _NoDataView(onRetry: ctrl.start, color: on),
      _ => _LoadingView(logoUrl: logo, color: on),
    };

    return Scaffold(
      backgroundColor: brand,
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(duration: Motion.base, child: KeyedSubtree(key: ValueKey(st.phase == SplashPhase.maintenance || st.phase == SplashPhase.update || st.phase == SplashPhase.noData ? st.phase : SplashPhase.loading), child: view)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.logoUrl, required this.color});

  final String logoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.str('common_allscreen_loading');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
          child: BrandLogo(size: 88, logoUrl: logoUrl),
        ),
        const SizedBox(height: 20),
        Text(AppEnv.appName, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const SizedBox(height: 28),
        LoadingPulse(color: color),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ],
    );
  }
}

/// First launch with no internet: no texts exist yet, so only icons.
class _NoDataView extends StatelessWidget {
  const _NoDataView({required this.onRetry, required this.color});

  final VoidCallback onRetry;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.cloud_off_rounded, size: 72, color: color),
      const SizedBox(height: 24),
      IconButton.filled(
        onPressed: onRetry,
        iconSize: 28,
        style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Theme.of(context).colorScheme.primary),
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.title, required this.message, required this.primary, this.secondary, this.badge});

  final IconData icon;
  final String title;
  final String message;
  final String? badge;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: context.primary),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(50)),
                  child: Text(badge!, style: TextStyle(color: tk.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45)),
            ],
            const SizedBox(height: 22),
            primary,
            if (secondary != null) ...[const SizedBox(height: 4), secondary!],
          ],
        ),
      ),
    );
  }
}