import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/brand_widgets.dart';
import 'auth_widgets.dart';

const _kSplitWidth = 900.0;

/// Phone / small tablet: brand header above the form. Wide: brand panel + form (same as Login).
class AuthSplitScaffold extends ConsumerWidget {
  const AuthSplitScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showStepTitleOnWide = true,
    this.onBack,
    this.brandTitleKey = 'auth_forgotpassword_forgotPassword',
    this.brandSubtitleKey = 'auth_forgotpassword_info',
    this.badge,
    this.badgeIcon = Icons.lock_rounded,
    this.formMaxWidth = 400,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// The first step's title is the same as the brand panel's headline, so it is not repeated.
  final bool showStepTitleOnWide;
  final VoidCallback? onBack;
  final String brandTitleKey;
  final String? brandSubtitleKey;
  final String? badge;
  final IconData badgeIcon;
  final double formMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final brand = context.primary;
    final on = onColor(brand);
    final logo = ref.watch(appConfigProvider)?.logoUrl ?? '';
    final split = MediaQuery.sizeOf(context).width >= _kSplitWidth;

    void back() {
      if (onBack != null) {
        onBack!();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.login);
      }
    }

    if (!split) {
      final top = MediaQuery.paddingOf(context).top;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: on == Colors.white ? Brightness.light : Brightness.dark,
          statusBarBrightness: on == Colors.white ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: tk.surface,
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: ColoredBox(
                    color: brand,
                    child: BrandBackdrop(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, top + 12, 24, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              onPressed: back,
                              style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
                              icon: Icon(Icons.arrow_back_rounded, color: on),
                            ),
                            const SizedBox(height: 18),
                            Text(title, style: TextStyle(color: on, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(subtitle!, style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), child: FadeSlideIn(child: child)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tk.surface,
      body: Row(
        children: [
          Expanded(
            flex: 10,
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
                            BrandLogo(size: 44, logoUrl: logo),
                            const SizedBox(width: 14),
                            Flexible(child: Text(AppEnv.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.w700))),
                          ],
                        ),
                        const Spacer(),
                        Text(context.str(brandTitleKey),
                            style: TextStyle(color: on, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1)),
                        if (brandSubtitleKey != null) ...[
                          const SizedBox(height: 14),
                          Text(context.str(brandSubtitleKey!), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 16, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: IconButton(
                        onPressed: back,
                        style: IconButton.styleFrom(side: BorderSide(color: tk.border)),
                        icon: Icon(Icons.arrow_back_rounded, color: tk.text1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: FadeSlideIn(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showStepTitleOnWide) ...[
                                  Text(title, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: tk.text1)),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(subtitle!, style: TextStyle(fontSize: 15, color: tk.text2, height: 1.45)),
                                  ],
                                  const SizedBox(height: 24),
                                ],
                                child,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}