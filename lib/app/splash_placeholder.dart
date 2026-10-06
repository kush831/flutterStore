import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/config/app_env.dart';
import '../core/router/app_redirect.dart';
import '../core/router/routes.dart';
import '../core/strings/strings_controller.dart';

/// Step 6 replaces this with the real splash. Same decision, minus the config checks.
class SplashPlaceholder extends ConsumerStatefulWidget {
  const SplashPlaceholder({super.key});

  @override
  ConsumerState<SplashPlaceholder> createState() => _SplashPlaceholderState();
}

class _SplashPlaceholderState extends ConsumerState<SplashPlaceholder> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      await ref.read(stringsProvider.notifier).ready.timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!mounted) return;
    context.go(startRoute(ref.read(authControllerProvider)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppEnv.appName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
          if (AppEnv.devTools) ...[
            const SizedBox(height: 24),
            OutlinedButton(onPressed: () => context.go(Routes.devHub), child: const Text('Dev hub')),
          ],
        ],
      ),
    ),
  );
}