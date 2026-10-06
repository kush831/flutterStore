import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/design/adaptive_page.dart';
import '../core/design/design_tokens.dart';
import '../core/network/session_events.dart';
import '../core/router/routes.dart';

const _destinations = <(String, String)>[
  ('Splash', Routes.splash),
  ('Welcome', Routes.welcome),
  ('Login', Routes.login),
  ('Signup', Routes.signup),
  ('Stripe documents', Routes.stripeDocuments),
  ('Upload documents', Routes.uploadDocuments),
  ('Dashboard', Routes.home),
  ('Orders', Routes.orders),
  ('Order #4821', '/orders/4821'),
  ('Products', Routes.products),
  ('Settings', Routes.more),
  ('Wallet', Routes.wallet),
  ('Store profile', Routes.storeProfile),
  ('API smoke test', Routes.devApi),
  ('Strings (missing keys)', Routes.devStrings),
  ('Design showcase', Routes.design),
  ('Unknown page', '/nothing-here'),
];

/// Developer tools (debug + Preview flavor only): test navigation, guards and the 999 flow
/// before the real login exists.
class DevHubPage extends ConsumerWidget {
  const DevHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final auth = ref.watch(authControllerProvider);
    final ctrl = ref.read(authControllerProvider.notifier);

    return AdaptivePage(
      title: 'Dev hub',
      subtitle: 'Not available in production builds',
      fallbackRoute: Routes.splash,
      scroll: true,
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                'signed in: ${auth.loggedIn}\n'
                    'signup status: ${auth.signupStatus}\n'
                    'notice: ${auth.notice ?? '-'}\n'
                    'return to page after login: ${auth.returnToAfterLogin}',
                style: TextStyle(color: tk.text2, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(onPressed: () => ctrl.devSignIn(), child: const Text('Sign in (status 0)')),
              OutlinedButton(onPressed: () => ctrl.devSignIn(signupStatus: 3), child: const Text('Sign in (status 3)')),
              OutlinedButton(onPressed: () => ctrl.devSignIn(signupStatus: 4), child: const Text('Sign in (status 4)')),
              OutlinedButton(onPressed: ctrl.signOut, child: const Text('Sign out')),
              OutlinedButton(
                onPressed: () => ref.read(sessionEventsProvider).sessionExpired('Your session has expired. Please sign in again.'),
                child: const Text('Simulate 999'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final (label, route) in _destinations) ...[
                  ListTile(
                    title: Text(label),
                    subtitle: Text(route, style: TextStyle(color: tk.text3, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(route),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}