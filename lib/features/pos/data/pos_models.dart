import '../../../core/network/json_reader.dart';

class PosServiceType {
  const PosServiceType({required this.id, this.name = '', this.type = 0, this.nameLocale = ''});

  final String id;
  final String name;
  final int type;
  final String nameLocale;

  factory PosServiceType.fromJson(JsonReader r) => PosServiceType(id: r.text('id'), name: r.text('serviceName'), type: r.integer('type') ?? 0, nameLocale: r.text('serviceNameLocale'));
}

class PosBusiness {
  const PosBusiness({this.id = '', this.name = '', this.phone = '', this.email = '', this.segmentId = '', this.segment = '', this.subGroup = 0, this.currency = '', this.serviceTypes = const []});

  final String id;
  final String name;
  final String phone;
  final String email;
  final String segmentId;
  final String segment;
  final int subGroup;
  final String currency;
  final List<PosServiceType> serviceTypes;

  factory PosBusiness.fromJson(JsonReader r) => PosBusiness(
    id: r.text('id'),
    name: r.text('name'),
    phone: r.text('phone'),
    email: r.text('email'),
    segmentId: r.text('segmentId'),
    segment: r.text('Segment'),
    subGroup: r.integer('segmentSubGroupApp') ?? 0,
    currency: r.text('currency'),
    serviceTypes: r.list('posServiceTypes', PosServiceType.fromJson),
  );
}

/// The staff member who signed in to POS, as `verify-pin` returns them. The permissions decide what the menus show.
class PosStaff {
  const PosStaff({required this.staffId, this.userId = '', this.name = '', this.roleId = 0, this.roleName = '', this.status = '', this.permissions = const [], this.business = const PosBusiness()});

  final String staffId;
  final String userId;
  final String name;
  final int roleId;
  final String roleName;
  final String status;
  final List<String> permissions;
  final PosBusiness business;

  factory PosStaff.fromJson(JsonReader d) => PosStaff(
    staffId: d.text('staffId'),
    userId: d.text('userId'),
    name: d.text('name'),
    roleId: d.integer('roleId') ?? 0,
    roleName: d.text('roleName'),
    status: d.text('currentStatus'),
    permissions: d.strings('permissions'),
    business: PosBusiness.fromJson(d.sub('businessSegment')),
  );
}

/// The shift (session) that is open for this staff member, if any.
class PosActiveSession {
  const PosActiveSession({required this.id, this.status = '', this.terminalName = '', this.terminalId = '',this.deviceId = '', this.openingCash = '', this.loginAt = '', this.totalOrders = '', this.totalRevenue = '', this.totalCashSales = ''});

  final String id;
  final String status;
  final String terminalName;
  final String terminalId;
  final String openingCash;
  final String loginAt;
  final String totalOrders;
  final String totalRevenue;
  final String totalCashSales;
  final String deviceId;

  /// Jetpack: only status "active" counts.
  bool get isActive => status.trim().toLowerCase() == 'active';

  factory PosActiveSession.fromJson(JsonReader r) => PosActiveSession(
    id: r.text('id'),
    status: r.text('status'),
    terminalName: r.text('terminalName'),
    terminalId: r.text('terminalId'),
    openingCash: r.text('openingCash'),
    loginAt: r.text('loginAt'),
    totalOrders: r.text('totalOrders'),
    totalRevenue: r.text('totalRevenue'),
    totalCashSales: r.text('totalCashSales'),
    deviceId: r.text('posDeviceId'),
  );
}

class PosHours {
  const PosHours({this.day = '', this.open = '', this.close = '', this.isOpen = false});

  final String day;
  final String open;
  final String close;
  final bool isOpen;

  factory PosHours.fromJson(JsonReader r) => PosHours(day: r.text('day'), open: r.text('openTime'), close: r.text('closeTime'), isOpen: r.flag('openClose'));
}

/// What the POS Store Profile shows (read only, as in Jetpack).
class PosMerchant {
  const PosMerchant({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.landmark = '',
    this.image = '',
    this.segment = '',
    this.joined = '',
    this.currency = '',
    this.rating = '',
    this.contactEmail = '',
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.hours = const [],
    this.bankName = '',
    this.bankHolder = '',
    this.bankAccount = '',
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String landmark;
  final String image;
  final String segment;
  final String joined;
  final String currency;
  final String rating;
  final String contactEmail;
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final List<PosHours> hours;
  final String bankName;
  final String bankHolder;
  final String bankAccount;

  factory PosMerchant.fromJson(JsonReader root) {
    final o = root.sub('data').sub('otherData');
    final m = o.sub('merchantDetails');
    final b = o.sub('bankDetails');
    return PosMerchant(
      name: o.text('name'),
      email: o.text('email'),
      phone: o.text('phone'),
      address: o.text('address'),
      landmark: o.text('landmark'),
      image: o.text('profileImage'),
      segment: o.text('segment'),
      joined: o.text('joinedDate'),
      currency: o.text('currency'),
      rating: o.text('rating'),
      contactEmail: o.text('contactUsEmail'),
      ownerName: m.text('name'),
      ownerPhone: m.text('phone'),
      ownerEmail: m.text('email'),
      hours: o.list('arrTime', PosHours.fromJson),
      bankName: b.text('bankName'),
      bankHolder: b.text('accountHolderName'),
      bankAccount: b.text('accountNumber'),
    );
  }
}