import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/demo_pages.dart' show DesignShowcasePage;
import '../../app/dev_hub_page.dart';
import '../../app/placeholder_screen.dart';
import '../../app/splash_placeholder.dart';
import '../../features/auth/logic/login_screen.dart';
import '../../features/auth/logic/signup_screen.dart';
import '../../features/auth/ui/demo_login_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/auth/ui/preview_login_screen.dart';
import '../../features/auth/ui/reset_password_screen.dart';
import '../../features/auth/ui/stripe_documents_screen.dart';
import '../../features/auth/ui/upload_documents_screen.dart';
import '../../features/auth/ui/verify_otp_screen.dart';
import '../../features/cms/ui/cms_page_screen.dart';
import '../../features/dev/api_smoke_page.dart';
import '../../features/dev/strings_dev_page.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/orders/ui/order_detail_screen.dart';
import '../../features/orders/ui/orders_screen.dart';
import '../../features/splash/ui/splash_screen.dart';
import '../../features/splash/ui/welcome_screen.dart';
import '../auth/auth_controller.dart';
import '../config/app_env.dart';
import '../design/adaptive_shell.dart';
import '../storage/storage_providers.dart';
import 'app_redirect.dart';
import 'routes.dart';

/// Tells GoRouter to re-run `redirect` whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  // The 4 tab pages: no slide animation when switching between them.
  GoRoute tab(String path, String title) => GoRoute(
    path: path,
    pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: PlaceholderScreen(title: title)),
  );

  GoRoute page(String path, String title, {String? back}) => GoRoute(
    path: path,
    builder: (_, _) => PlaceholderScreen(title: title, fallbackRoute: back),
  );

  GoRoute open(String path, String title) => GoRoute(
    path: path,
    builder: (_, _) => PlaceholderScreen(title: title, standalone: true),
  );

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      fullLocation: state.uri.toString(),
      auth: ref.read(authControllerProvider),
      devEnabled: AppEnv.devTools,
      membershipEnabled: ref.read(appPrefsProvider).membershipEnabled,
    ),
    errorBuilder: (context, state) => const PlaceholderScreen(
      title: 'Page not found',
      standalone: true,
      fallbackRoute: Routes.splash,
    ),
    routes: [
      // ── before the app: full screen, no shell ──────────────────────────────
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, state) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.verifyOtp, builder: (_, _) => const VerifyOtpScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(path: Routes.previewLogin, builder: (_, _) => const PreviewLoginScreen()),
      GoRoute(path: Routes.demoLogin, builder: (_, _) => const DemoLoginScreen()),
      GoRoute(
        path: '/cms/:slug',
        builder: (_, state) => CmsPageScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(path: Routes.stripeDocuments, builder: (_, _) => const StripeDocumentsScreen()),
      GoRoute(path: Routes.uploadDocuments, builder: (_, _) => const UploadDocumentsScreen()),

      // ── developer tools ────────────────────────────────────────────────────
      GoRoute(path: Routes.devHub, builder: (_, _) => const DevHubPage()),
      GoRoute(path: Routes.devApi, builder: (_, _) => const ApiSmokePage()),
      GoRoute(path: Routes.devStrings, builder: (_, _) => const StringsDevPage()),
      GoRoute(path: Routes.design, builder: (_, _) => const DesignShowcasePage()),

      // ── the app: every private page lives inside the adaptive shell ────────
      ShellRoute(
        builder: (context, state, child) => AdaptiveShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, s) => NoTransitionPage(key: s.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: Routes.orders,
            pageBuilder: (_, s) => NoTransitionPage(
              key: s.pageKey,
              child: OrdersScreen(tabParam: s.uri.queryParameters['tab']),
            ),
          ),
          GoRoute(
            path: '${Routes.orders}/:id',
            builder: (_, s) => OrderDetailScreen(id: s.pathParameters['id'] ?? ''),
          ),
          tab(Routes.products, 'Products'),
          page(Routes.productAdd, 'Add product', back: Routes.products), // before ':id'
          page(Routes.manageStock, 'Manage stock', back: Routes.products),
          GoRoute(
            path: '${Routes.products}/:id',
            builder: (_, s) => PlaceholderScreen(title: 'Product ${s.pathParameters['id']}', fallbackRoute: Routes.products),
          ),
          tab(Routes.more, 'Settings'),
          page(Routes.analytics, 'Analytics'),
          page(Routes.earnings, 'Earnings'),
          page(Routes.wallet, 'Wallet'),
          page(Routes.cashout, 'Cashout'),
          page(Routes.categories, 'Categories'),
          page(Routes.options, 'Options'),
          page(Routes.storeProfile, 'Store profile'),
          page(Routes.timings, 'Store timings'),
          page(Routes.membership, 'Membership'),
        ],
      ),
    ],
  );
});