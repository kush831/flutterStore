/// The permission texts the server sends in `permissions` (Jetpack's PosPermissions).
abstract final class PosPerm {
  static const ordersCreate = 'orders:create';
  static const ordersDiscount = 'orders:apply_discount';
  static const ordersCancel = 'orders:cancel';
  static const ordersRefund = 'orders:refund';
  static const ordersVoid = 'orders:void';
  static const ordersProcess = 'orders:process';
  static const ordersReady = 'orders:ready';
  static const ordersComplete = 'orders:complete';
  static const reportsView = 'reports:view';
  static const staffManage = 'staff:manage';
  static const staffView = 'staff:view';
  static const terminalManage = 'terminal:manage';
  static const terminalView = 'terminal:view';
  static const openSession = 'pos:open_session';
  static const closeSession = 'pos:close_session';
  static const forceTransfer = 'pos:force_transfer';
  static const viewAllSessions = 'pos:view_all_sessions';
}