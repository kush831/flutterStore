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
  /// /products?type=OUTOFSTOCK | LOWSTOCK
  static String productsFiltered(String type) => '$products?type=$type';
  static String productEdit(String id) => '$products/$id/edit';
  static const storeProfileEdit = '$storeProfile/edit';
  static const timeSlabs = '$storeProfile/time-slabs';
  static const push = '/push'; // the deep link a native notification opens
  static const packaging = '$storeProfile/packaging';

  // ── developer tools (debug + Preview flavor only) ─────────────────────────
  static const devHub = '/dev';
  static const devApi = '/dev/api';
  static const devStrings = '/dev/strings';
  static const design = '/dev/design';
  static const manageStock = '/products/stock';


  // --------- Pos routes -------------------
  static const pos = '/pos'; // the POS dashboard
  static const posLogin = '/pos/login';
  static const posStart = '/pos/start';
  static const posProducts = '/pos/products';
  static const posOrders = '/pos/orders';
  static const posMore = '/pos/more';
  static const posOpenSession = '/pos/open-session';
  static const posStoreProfile = '/pos/store-profile';
  static const posSessions = '/pos/sessions';
  static const posTerminals = '/pos/terminals';
  static const posStaff = '/pos/staff';
  static const posAnalytics = '/pos/analytics';
  static const posCloseSession = '/pos/close-session';
  static const posSessionClosed = '/pos/session-closed';
  static const posHandover = '/pos/handover';
  static const posTransfer = '/pos/transfer-terminal';
  static const posShiftHistory = '/pos/shift-history';
  static const posAllSessions = '/pos/all-sessions';
  static const posCategories = '/pos/categories';
  static const posCategory = '/pos/category'; // + /:id?name=…&sub=1
  static const posCart = '/pos/cart'; // P4
  static const posSearch = '/pos/search'; // 30B
  static const posProduct = '/pos/product'; // 30B + /:id
  static const posScan = '/pos/scan';
  static const posHeldCarts = '/pos/held-carts';
  static const posPayment = '/pos/payment'; // 31B
  static const posOrderSuccess = '/pos/order-success';
  static const posReceipt = '/pos/receipt'; // + /:orderId
  static const posOrderQueue = '/pos/order-queue';
  static const posOrder = '/pos/order'; // + /:id
  static const posAllStaff = '/pos/staff/all';
  static const posStaffMember = '/pos/staff/member'; // + /:id
  static const posStatusHistory = '/pos/staff/history'; // + /:id
  static const posRoles = '/pos/roles'; // 33B

}