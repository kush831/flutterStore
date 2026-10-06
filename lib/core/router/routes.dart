/// Every route of a section lives under its prefix, so the sidebar can highlight it:
/// /orders, /orders/:id · /products, /products/add · /store/profile · /finance/wallet …
abstract final class Routes {
  // ── before login ──────────────────────────────────────────────────────────
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const verifyOtp = '/verify-otp';
  static const resetPassword = '/reset-password';
  static const previewLogin = '/preview-login';
  static const demoLogin = '/demo-login';
  static String cms(String slug) => '/cms/$slug';

  // ── after login, before the app (signup_status 3 / 4) ─────────────────────
  static const stripeDocuments = '/stripe-documents';
  static const uploadDocuments = '/upload-documents';

  // ── the app (inside the shell) ────────────────────────────────────────────
  static const home = '/home';
  static const orders = '/orders';
  static const products = '/products';
  static const productAdd = '/products/add';
  static const more = '/more';
  static const analytics = '/analytics';
  static const earnings = '/finance/earnings';
  static const wallet = '/finance/wallet';
  static const cashout = '/finance/cashout';
  static const categories = '/store/categories';
  static const options = '/store/options';
  static const storeProfile = '/store/profile';
  static const timings = '/store/timings';
  static const membership = '/membership';

  static String orderDetail(String id) => '$orders/$id';
  static String productDetail(String id) => '$products/$id';
  static String ordersTab(String tab) => '$orders?tab=$tab';

  // ── developer tools (debug + Preview flavor only) ─────────────────────────
  static const devHub = '/dev';
  static const devApi = '/dev/api';
  static const devStrings = '/dev/strings';
  static const design = '/dev/design';
  static const manageStock = '/products/stock';

}