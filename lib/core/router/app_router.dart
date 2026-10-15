import 'package:apporio_store_30sept/features/more/ui/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/demo_pages.dart' show DesignShowcasePage;
import '../../app/dev_hub_page.dart';
import '../../app/placeholder_screen.dart';
import '../../features/analytics/ui/analytics_screen.dart';
import '../../features/auth/logic/login_screen.dart';
import '../../features/auth/logic/signup_screen.dart';
import '../../features/auth/ui/demo_login_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/auth/ui/preview_login_screen.dart';
import '../../features/auth/ui/reset_password_screen.dart';
import '../../features/auth/ui/stripe_documents_screen.dart';
import '../../features/auth/ui/upload_documents_screen.dart';
import '../../features/auth/ui/verify_otp_screen.dart';
import '../../features/catalog/ui/categories_screen.dart';
import '../../features/catalog/ui/options_screen.dart';
import '../../features/cms/ui/cms_page_screen.dart';
import '../../features/dev/api_smoke_page.dart';
import '../../features/dev/strings_dev_page.dart';
import '../../features/finance/ui/cashout_screen.dart';
import '../../features/finance/ui/earnings_screen.dart';
import '../../features/finance/ui/wallet_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/membership/ui/membership_screen.dart';
import '../../features/orders/ui/order_detail_screen.dart';
import '../../features/orders/ui/orders_screen.dart';
import '../../features/packaging/ui/packaging_screen.dart';
import '../../features/pos/data/pos_catalog_models.dart';
import '../../features/pos/data/pos_shift_models.dart';
import '../../features/pos/logic/pos_auth.dart';
import '../../features/pos/logic/pos_sale.dart';
import '../../features/pos/ui/pos_all_sessions_screen.dart';
import '../../features/pos/ui/pos_analytics_screen.dart';
import '../../features/pos/ui/pos_barcode_scanner_screen.dart';
import '../../features/pos/ui/pos_cart_screen.dart';
import '../../features/pos/ui/pos_close_session_screen.dart';
import '../../features/pos/ui/pos_dashboard_screen.dart';
import '../../features/pos/ui/pos_handover_screen.dart';
import '../../features/pos/ui/pos_held_carts_screen.dart';
import '../../features/pos/ui/pos_login_screen.dart';
import '../../features/pos/ui/pos_more_screen.dart';
import '../../features/pos/ui/pos_open_session_screen.dart';
import '../../features/pos/ui/pos_order_detail_screen.dart';
import '../../features/pos/ui/pos_order_queue_screen.dart';
import '../../features/pos/ui/pos_order_success_screen.dart';
import '../../features/pos/ui/pos_orders_screen.dart';
import '../../features/pos/ui/pos_payment_screen.dart';
import '../../features/pos/ui/pos_product_detail_screen.dart';
import '../../features/pos/ui/pos_products_screens.dart';
import '../../features/pos/ui/pos_receipt_screen.dart';
import '../../features/pos/ui/pos_roles_screen.dart';
import '../../features/pos/ui/pos_search_screen.dart';
import '../../features/pos/ui/pos_session_closed_screen.dart';
import '../../features/pos/ui/pos_session_screen.dart';
import '../../features/pos/ui/pos_shell.dart';
import '../../features/pos/ui/pos_shift_history_screen.dart';
import '../../features/pos/ui/pos_staff_detail_screen.dart';
import '../../features/pos/ui/pos_staff_screen.dart';
import '../../features/pos/ui/pos_start_screen.dart';
import '../../features/pos/ui/pos_store_profile_screen.dart';
import '../../features/pos/ui/pos_terminals_screen.dart';
import '../../features/pos/ui/pos_transfer_screen.dart';
import '../../features/products/ui/product_detail_screen.dart';
import '../../features/products/ui/product_form_screen.dart';
import '../../features/products/ui/products_screen.dart';
import '../../features/push/data/push_event.dart';
import '../../features/push/logic/order_alarm.dart';
import '../../features/splash/ui/splash_screen.dart';
import '../../features/splash/ui/welcome_screen.dart';
import '../../features/store/ui/slabs_screen.dart';
import '../../features/store/ui/store_edit_screen.dart';
import '../../features/store/ui/store_profile_screen.dart';
import '../../features/store/ui/store_timings_screen.dart';
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
    _posSub = ref.listen<PosAuthState>(posAuthProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AuthState> _sub;
  late final ProviderSubscription<PosAuthState> _posSub;

  @override
  void dispose() {
    _sub.close();
    _posSub.close();
    super.dispose();
  }
}

/// A POS page: "/pos" itself or anything under "/pos/". (Whole segments only.)
bool _isPosPath(String p) => p == Routes.pos || p.startsWith('${Routes.pos}/');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      fullLocation: state.uri.toString(),
      auth: ref.read(authControllerProvider),
      devEnabled: AppEnv.devTools,
      membershipEnabled: ref.read(appPrefsProvider).membershipEnabled,
      posLoggedIn: ref.read(posAuthProvider).loggedIn,
    ),
    errorBuilder: (context, state) => const PlaceholderScreen(
      title: 'Page not found',
      standalone: true,
      fallbackRoute: Routes.splash,
    ),
    routes: [
      GoRoute(
        path: Routes.push,
        redirect: (context, state) {
          final e = PushEvent.fromUri(state.uri);
          if (e.isNewOrder || e.type == PushType.orderExpired) ref.read(orderAlarmProvider).stop(e.orderId);
          return pushRoute(e) ?? Routes.home;
        },
      ),
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
      // (POS pages are given no store shell: they have their own, PosShell, below)
      ShellRoute(
        builder: (context, state, child) => _isPosPath(state.uri.path) ? child : AdaptiveShell(location: state.uri.path, child: child),
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
          GoRoute(
            path: Routes.products,
            pageBuilder: (_, s) => NoTransitionPage(
              key: s.pageKey,
              child: ProductsScreen(typeParam: s.uri.queryParameters['type']),
            ),
          ),
          GoRoute(path: Routes.productAdd, builder: (_, _) => const ProductFormScreen()),
          GoRoute(path: '${Routes.products}/:id/edit', builder: (_, s) => ProductFormScreen(productId: s.pathParameters['id'])),
          GoRoute(path: Routes.manageStock, builder: (_, _) => const ProductsScreen(typeParam: 'OUTOFSTOCK')), // before ':id'
          GoRoute(path: '${Routes.products}/:id', builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id'] ?? '')),
          GoRoute(path: Routes.categories, builder: (_, _) => const CategoriesScreen()),
          GoRoute(path: Routes.options, builder: (_, _) => const OptionsScreen()),
          GoRoute(path: Routes.more, builder: (_, _) => const MoreScreen()),
          GoRoute(path: Routes.analytics, builder: (_, _) => const AnalyticsScreen()),
          GoRoute(path: Routes.earnings, builder: (_, _) => const EarningsScreen()),
          GoRoute(path: Routes.wallet, builder: (_, _) => const WalletScreen()),
          GoRoute(path: Routes.cashout, builder: (_, _) => const CashoutScreen()),
          GoRoute(path: Routes.storeProfile, builder: (_, _) => const StoreProfileScreen()),
          GoRoute(path: Routes.timeSlabs, builder: (_, _) => const SlabsScreen()),
          GoRoute(path: Routes.packaging, builder: (_, _) => const PackagingScreen()),
          GoRoute(path: Routes.storeProfileEdit, builder: (_, _) => const StoreEditScreen()),
          GoRoute(path: Routes.timings, builder: (_, _) => const StoreTimingsScreen()),
          GoRoute(path: Routes.membership, builder: (_, _) => const MembershipScreen()),

          // ── POS: before the frame (full screen) ────────────────────────────
          GoRoute(path: Routes.posLogin, builder: (_, _) => const PosLoginScreen()),
          GoRoute(path: Routes.posStart, builder: (_, _) => const PosStartScreen()),
          GoRoute(path: Routes.posOpenSession, builder: (_, _) => const PosOpenSessionScreen()),

          // ── POS: every page inside the POS frame (bottom bar, rail or sidebar) ──
          ShellRoute(
            builder: (context, state, child) => PosShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(path: Routes.pos, pageBuilder: (c, s) => const NoTransitionPage(child: PosDashboardScreen())),
              GoRoute(path: Routes.posProducts, pageBuilder: (c, s) => const NoTransitionPage(child: PosProductsEntry())),
              GoRoute(path: Routes.posOrders, pageBuilder: (c, s) => NoTransitionPage(child: PosOrdersScreen(initialTab: s.uri.queryParameters['tab']))),
              GoRoute(path: Routes.posMore, pageBuilder: (c, s) => const NoTransitionPage(child: PosMoreScreen())),
              GoRoute(path: Routes.posStoreProfile, builder: (_, _) => const PosStoreProfileScreen()),
              GoRoute(path: Routes.posAnalytics, builder: (_, _) => const PosAnalyticsScreen()),
              GoRoute(path: Routes.posSessions, builder: (_, _) => const PosSessionScreen()),
              GoRoute(path: Routes.posTerminals, builder: (_, _) => const PosTerminalsScreen()),
              GoRoute(path: Routes.posCloseSession, builder: (_, _) => const PosCloseSessionScreen()),
              GoRoute(
                path: Routes.posSessionClosed,
                redirect: (_, s) => s.extra is PosCloseResult ? null : Routes.posSessions, // the summary is passed in; after a page reload go to Sessions
                builder: (_, s) => PosSessionClosedScreen(result: s.extra as PosCloseResult),
              ),
              GoRoute(path: Routes.posHandover, builder: (_, _) => const PosHandoverScreen()),
              GoRoute(path: Routes.posTransfer, builder: (_, _) => const PosTransferScreen()),
              GoRoute(path: Routes.posShiftHistory, builder: (_, _) => const PosShiftHistoryScreen()),
              GoRoute(path: Routes.posAllSessions, builder: (_, _) => const PosAllSessionsScreen()),
              GoRoute(path: Routes.posCategories, builder: (_, _) => const PosCategoriesScreen()),
              GoRoute(
                path: '${Routes.posCategory}/:id',
                builder: (_, s) => PosCategoryProductsScreen(categoryId: s.pathParameters['id'] ?? '', name: s.uri.queryParameters['name'] ?? '', hasSub: s.uri.queryParameters['sub'] == '1'),
              ),
              GoRoute(path: Routes.posCart, builder: (_, _) => const PosCartScreen()),
              GoRoute(path: Routes.posHeldCarts, builder: (_, _) => const PosHeldCartsScreen()),
              GoRoute(path: Routes.posSearch, builder: (_, _) => const PosSearchScreen()),
              GoRoute(path: Routes.posScan, builder: (_, _) => const PosBarcodeScannerScreen()),
              GoRoute(
                path: '${Routes.posProduct}/:id',
                builder: (_, s) => PosProductDetailScreen(productId: s.pathParameters['id'] ?? '', product: s.extra is PosProduct ? s.extra as PosProduct : null),
              ),
              GoRoute(path: Routes.posPayment, builder: (_, _) => const PosPaymentScreen()),
              GoRoute(path: Routes.posOrderQueue, builder: (_, _) => const PosOrderQueueScreen()),
              GoRoute(path: '${Routes.posOrder}/:id', builder: (_, s) => PosOrderDetailScreen(orderId: s.pathParameters['id'] ?? '')),
              GoRoute(
                path: Routes.posOrderSuccess,
                redirect: (_, _) => ref.read(posLastSaleProvider) == null ? Routes.posProducts : null, // nothing was just sold (a page reload)
                builder: (_, _) => const PosOrderSuccessScreen(),
              ),
              GoRoute(path: '${Routes.posReceipt}/:id', builder: (_, s) => PosReceiptScreen(orderId: s.pathParameters['id'] ?? '')),
              GoRoute(path: Routes.posStaff, builder: (_, _) => const PosStaffScreen()),
              GoRoute(path: Routes.posAllStaff, builder: (_, _) => const PosAllStaffScreen()),
              GoRoute(path: '${Routes.posStaffMember}/:id', builder: (_, s) => PosStaffDetailScreen(staffId: s.pathParameters['id'] ?? '')),
              GoRoute(path: '${Routes.posStatusHistory}/:id', builder: (_, s) => PosStatusHistoryScreen(staffId: s.pathParameters['id'] ?? '', name: s.uri.queryParameters['name'] ?? '')),
              GoRoute(path: Routes.posRoles, builder: (_, _) => const PosRolesScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});