import '../../../core/network/json_reader.dart';

class OrderOption {
  const OrderOption({required this.name, this.amount = ''});

  final String name;
  final String amount;

  factory OrderOption.fromJson(JsonReader r) => OrderOption(name: r.text('optionName'), amount: r.text('amount'));
}

class OrderLine {
  const OrderLine({
    required this.name,
    this.variant = '',
    this.value = '',
    this.bold = false,
    this.quantity = 0,
    this.discount = '',
    this.image = '',
    this.options = const [],
  });

  final String name;
  final String variant;
  final String value; // already formatted by the server
  final bool bold;
  final int quantity;
  final String discount;
  final String image;
  final List<OrderOption> options;

  /// "0", "0.00" and "" mean no discount.
  bool get hasDiscount => !RegExp(r'^[0\s.,]*$').hasMatch(discount);

  factory OrderLine.fromJson(JsonReader r) => OrderLine(
    name: r.text('name'),
    variant: r.text('productVariant'),
    value: r.text('value'),
    bold: r.flag('bold'),
    quantity: r.integer('items') ?? 0,
    discount: r.text('discount'),
    image: r.text('productImage'),
    options: r.list('arrOptions', OrderOption.fromJson),
  );
}

class BillRow {
  const BillRow({required this.name, this.value = '', this.bold = false});

  final String name;
  final String value;
  final bool bold;

  factory BillRow.fromJson(JsonReader r) => BillRow(name: r.text('name'), value: r.text('value'), bold: r.flag('bold'));
}

class PaymentInfo {
  const PaymentInfo({this.paidStatus = '', this.mode = '', this.amount = '', this.currency = ''});

  final String paidStatus;
  final String mode;
  final String amount;
  final String currency;
}

class CustomerInfo {
  const CustomerInfo({this.name = '', this.phone = '', this.address = ''});

  final String name;
  final String phone;
  final String address;
}

class DriverInfo {
  const DriverInfo({this.name = '', this.phone = '', this.rating = ''});

  final String name;
  final String phone;
  final String rating;
}

/// The server decides which buttons an order has (Accept, Reject, Process …). 14C uses these.
class OrderAction {
  const OrderAction({required this.text, required this.colour, required this.action});

  final String text;
  final String colour;
  final String action;

  factory OrderAction.fromJson(JsonReader r) =>
      OrderAction(text: r.text('buttonText'), colour: r.text('buttonTextColour'), action: r.text('buttonAction'));
}

class TimelineStep {
  const TimelineStep({this.text = '', this.time = '', this.icon = ''});

  final String text;
  final String time; // unix seconds as text, '' while the step has not happened
  final String icon; // an image URL from the server (tick / empty circle)

  bool get done => time.trim().isNotEmpty;

  DateTime? get at {
    final n = int.tryParse(time.trim());
    if (n == null || n <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(n > 1000000000000 ? n : n * 1000);
  }

  factory TimelineStep.fromJson(JsonReader r) => TimelineStep(text: r.text('statusText'), time: r.text('statusTime'), icon: r.text('tickIcon'));
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.number,
    this.status = 0,
    this.statusText = '',
    this.orderTime = '',
    this.deliverOn = '',
    this.totalItems = 0,
    this.lines = const [],
    this.bill = const [],
    this.payment = const PaymentInfo(),
    this.customer,
    this.driver,
    this.actions = const [],
    this.invoiceUrl = '',
    this.notes = '',
    this.cooking = '',
    this.instructionOptions = const [],
    this.timeline = const [],
    this.serviceType = '',
    this.processOtp = '',
    this.otpBypass = false,
  });

  final int id;
  final int number;
  final int status;
  final String statusText;
  final String orderTime;
  final String deliverOn;
  final int totalItems;
  final List<OrderLine> lines;
  final List<BillRow> bill;
  final PaymentInfo payment;
  final CustomerInfo? customer;
  final DriverInfo? driver;
  final List<OrderAction> actions;
  final String invoiceUrl;
  final String notes;
  final String cooking;
  final List<String> instructionOptions;
  final List<TimelineStep> timeline;
  final String serviceType;

  /// ⚠️ The server sends the process OTP to the app (used by 14C). It is never shown on screen.
  final String processOtp;
  final bool otpBypass;

  static JsonReader _payload(JsonReader root) {
    final inData = root.sub('data');
    return inData.sub('details').integer('id') != null ? inData : root;
  }

  factory OrderDetail.fromJson(JsonReader root) {
    final d = _payload(root);
    final h = d.sub('details');
    final p = d.sub('paymentDetails');
    final c = d.sub('customerDetails');
    final dr = d.sub('driverDetails');

    final customer = CustomerInfo(name: c.text('customerName'), phone: c.text('customerPhone'), address: c.text('dropLocation'));
    final driver = DriverInfo(name: dr.text('driverName'), phone: dr.text('driverPhone'), rating: dr.text('driverRating'));
    final deliver = h.text('deliverOnFormatted');

    return OrderDetail(
      id: h.integer('id') ?? 0,
      number: h.integer('number') ?? 0,
      status: h.integer('status') ?? 0,
      statusText: h.text('statusText'),
      orderTime: h.text('orderTime'),
      deliverOn: deliver.isNotEmpty ? deliver : h.text('deliverOn'),
      totalItems: h.integer('totalItems') ?? 0,
      lines: d.list('productDetails', OrderLine.fromJson),
      bill: d.list('billDetails', BillRow.fromJson),
      payment: PaymentInfo(paidStatus: p.text('paidStatus'), mode: p.text('paymentMode'), amount: p.text('amount'), currency: p.text('currency')),
      customer: (customer.name.isEmpty && customer.phone.isEmpty && customer.address.isEmpty) ? null : customer,
      driver: driver.name.isEmpty ? null : driver,
      actions: d.list('actionButtons', OrderAction.fromJson),
      invoiceUrl: d.text('invoiceUrl'),
      notes: d.text('additionalNotes'),
      cooking: d.text('cookingInstruction'),
      instructionOptions: d.strings('instructionOptions'),
      timeline: d.list('orderStatusHolder', TimelineStep.fromJson),
      serviceType: d.text('serviceType'),
      processOtp: d.text('orderProcessOtp'),
      otpBypass: d.flag('orderProcessOtpByPass'),
    );
  }
}