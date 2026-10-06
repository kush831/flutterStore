import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/demo_repository.dart';
import '../logic/login_controller.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

/// The demo accounts share one password (Preview flavor only).
const _kDemoPassword = '12345678';

class DemoLoginScreen extends ConsumerStatefulWidget {
  const DemoLoginScreen({super.key});

  @override
  ConsumerState<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends ConsumerState<DemoLoginScreen> {
  bool _food = true;
  String? _selected;

  Future<void> _login() async {
    final email = _selected;
    if (email == null) return;
    // the router moves the user on once the sign-in succeeds
    await ref.read(loginControllerProvider.notifier).submit(isEmail: true, identifier: email, password: _kDemoPassword);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(demoAccountsProvider);
    final login = ref.watch(loginControllerProvider);
    final list = async.value == null ? const <String>[] : (_food ? async.value!.food : async.value!.grocery);

    Widget body;
    if (async.isLoading) {
      body = SkeletonPulse(
        child: Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(height: 58, radius: 12))]),
      );
    } else if (async.hasError) {
      body = Column(
        children: [
          AuthBanner(tone: AuthTone.danger, text: errorText(async.error!, ref.read(stringsProvider))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => ref.invalidate(demoAccountsProvider), child: Text(context.str('common_allscreen_try_again'))),
        ],
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.person_search_rounded, size: 44, color: tk.text3),
            const SizedBox(height: 10),
            Text(context.str('auth_demostoresview_noDemoUsersFound'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 4),
            Text(context.str('auth_demostoresview_trySwitchingCategoryAbove'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          for (final email in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountTile(
                email: email,
                selected: email == _selected,
                onTap: login.busy ? null : () => setState(() => _selected = email),
              ),
            ),
        ],
      );
    }

    return AuthSplitScaffold(
      title: context.str('auth_demostoresview_select_title'),
      subtitle: context.str('auth_demostoresview_select_subtitle'),
      brandTitleKey: 'auth_demostoresview_select_title',
      brandSubtitleKey: 'auth_demostoresview_select_subtitle',
      showStepTitleOnWide: false,
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.login),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSegmented(
            isFirst: _food,
            firstLabel: context.str('auth_demostoresview_food_segment'),
            secondLabel: context.str('auth_demostoresview_grocery_segment'),
            onChanged: (v) => setState(() {
              _food = v;
              _selected = null; // never sign in to an account that is not on screen
            }),
          ),
          const SizedBox(height: 16),
          body,
          const SizedBox(height: 10),
          if (login.banner != null) ...[
            AuthBanner(tone: AuthTone.danger, text: login.banner!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: (_selected == null || login.busy) ? null : _login,
            child: login.busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(context.str(_selected == null ? 'auth_demostoresview_selectDemoAccount' : 'auth_demostoresview_login_button')),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.email, required this.selected, required this.onTap});

  final String email;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.08) : tk.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? primary : tk.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: selected ? primary : tk.sunken,
                child: Text(email[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : tk.text1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: tk.text1)),
                    const SizedBox(height: 2),
                    Text(context.str(selected ? 'auth_demostoresview_selected' : 'auth_demostoresview_tapToSelect'),
                        style: TextStyle(fontSize: 12, color: selected ? primary : tk.text3)),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? primary : tk.border),
            ],
          ),
        ),
      ),
    );
  }
}