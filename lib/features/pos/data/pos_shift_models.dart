import '../../../core/network/json_reader.dart';

class PosTerminal {
  const PosTerminal({
    required this.id,
    this.name = '',
    this.code = '',
    this.type = '',
    this.deviceId = '',
    this.locationNote = '',
    this.isActive = false,
    this.isInUse = false,
    this.inUseBy = '',
    this.sessionId = '',
  });

  final String id;
  final String name;
  final String code;
  final String type; // counter · kiosk · mobile
  final String deviceId;
  final String locationNote;
  final bool isActive;
  final bool isInUse;
  final String inUseBy; // the operator
  final String sessionId;

  /// Free to start a shift on: active and not in use.
  bool get available => isActive && !isInUse;

  /// Jetpack sends the device id, or the code when the device id is empty, as `pos_device_id`.
  String get deviceKey => deviceId.trim().isNotEmpty ? deviceId : code;

  factory PosTerminal.fromJson(JsonReader r) => PosTerminal(
    id: r.text('id'),
    name: r.text('name'),
    code: r.text('code'),
    type: r.text('type'),
    deviceId: r.text('deviceId'),
    locationNote: r.text('locationNote'),
    isActive: r.flag('isActive'),
    isInUse: r.flag('isInUse'),
    inUseBy: r.text('inUseBy'),
    sessionId: r.text('sessionId'),
  );
}

class PosOpenResult {
  const PosOpenResult({required this.sessionId, this.openingCash = '', this.terminalName = '', this.openedAt = ''});

  final String sessionId;
  final String openingCash;
  final String terminalName;
  final String openedAt;

  factory PosOpenResult.fromJson(JsonReader r) => PosOpenResult(sessionId: r.text('sessionId'), openingCash: r.text('openingCash'), terminalName: r.text('terminalName'), openedAt: r.text('openedAt'));
}

/// What the server answers when a shift is closed.
class PosCloseResult {
  const PosCloseResult({this.totalOrders = 0, this.totalRevenue = 0, this.totalCashSales = 0, this.openingCash = 0, this.closingCash = 0, this.cashDifference = 0, this.closedAt = ''});

  final int totalOrders;
  final double totalRevenue;
  final double totalCashSales;
  final double openingCash;
  final double closingCash;
  final double cashDifference; // counted − expected: above 0 a surplus, below 0 a shortage
  final String closedAt;

  factory PosCloseResult.fromJson(JsonReader r) => PosCloseResult(
    totalOrders: r.integer('totalOrders') ?? 0,
    totalRevenue: r.number('totalRevenue') ?? 0,
    totalCashSales: r.number('totalCashSales') ?? 0,
    openingCash: r.number('openingCash') ?? 0,
    closingCash: r.number('closingCash') ?? 0,
    cashDifference: r.number('cashDifference') ?? 0,
    closedAt: r.text('closedAt'),
  );
}

/// One row of "My Shift History".
class PosShift {
  const PosShift({required this.sessionId, this.staffName = '', this.terminalName = '', this.openingCash, this.closingCash, this.loginAt = '', this.logoutAt = '', this.status = ''});

  final String sessionId;
  final String staffName;
  final String terminalName;
  final double? openingCash;
  final double? closingCash;
  final String loginAt;
  final String logoutAt;
  final String status;

  bool get isActive => status.trim().toLowerCase() == 'active';

  /// Jetpack's "cash diff": closing minus opening, only when both are known.
  double? get cashDiff => (openingCash != null && closingCash != null) ? closingCash! - openingCash! : null;

  factory PosShift.fromJson(JsonReader r) => PosShift(
    sessionId: r.text('sessionId'),
    staffName: r.text('staffName'),
    terminalName: r.text('posTerminalName'),
    openingCash: r.number('openingCash'),
    closingCash: r.number('closingCash'),
    loginAt: r.text('loginAt'),
    logoutAt: r.text('logoutAt'),
    status: r.text('status'),
  );
}

/// One row of "All Sessions" (the manager's view).
class PosManagerSession {
  const PosManagerSession({
    required this.sessionId,
    this.terminal = '',
    this.terminalId = '',
    this.deviceId = '',
    this.terminalStatus = '',
    this.cashier = '',
    this.status = '',
    this.openingCash = '0',
    this.cashSales = '0',
    this.expectedDrawer = '0',
    this.loginAt = '',
    this.logoutAt = '',
  });

  final String sessionId;
  final String terminal;
  final String terminalId;
  final String deviceId;
  final String terminalStatus;
  final String cashier;
  final String status;
  final String openingCash;
  final String cashSales;
  final String expectedDrawer;
  final String loginAt;
  final String logoutAt;

  bool get isActive => status.trim().toLowerCase() == 'active';

  factory PosManagerSession.fromJson(JsonReader r) => PosManagerSession(
    sessionId: r.text('sessionId'),
    terminal: r.text('terminal'),
    terminalId: r.text('posTerminalId'),
    deviceId: r.text('posDeviceId'),
    terminalStatus: r.text('terminalStatus'),
    cashier: r.text('cashierName'),
    status: r.text('status'),
    openingCash: r.text('openingCash', '0'),
    cashSales: r.text('cashSales', '0'),
    expectedDrawer: r.text('expectedDrawer', '0'),
    loginAt: r.text('loginAt'),
    logoutAt: r.text('logoutAt'),
  );
}