import '../../../core/network/json_reader.dart';
import '../logic/pos_shift_logic.dart' show posNum;

/// One row of the bill the server calculates (Subtotal, Tax, Discount, Total …).
class PosBillRow {
  const PosBillRow({this.name = '', this.value = '', this.valueFormatted = '', this.bold = false});

  final String name;
  final String value;
  final String valueFormatted;
  final bool bold;

  factory PosBillRow.fromJson(JsonReader r) => PosBillRow(name: r.text('name'), value: r.text('value'), valueFormatted: r.text('valueFormatted'), bold: r.flag('bold'));
}

/// A way to pay, as the server offers it for this cart.
class PosPaymentMethod {
  const PosPaymentMethod({required this.id, this.name = '', this.action = false, this.icon = '', this.message = '', this.cardId = ''});

  final String id;
  final String name;
  final bool action;
  final String icon;
  final String message;
  final String cardId;

  factory PosPaymentMethod.fromJson(JsonReader r) => PosPaymentMethod(id: r.text('id'), name: r.text('name'), action: r.flag('action'), icon: r.text('icon'), message: r.text('message'), cardId: r.text('cardId'));
}

/// A line of the cart as the server priced it.
class PosQuoteLine {
  const PosQuoteLine({this.variantId = '', this.name = '', this.quantity = 0, this.totalPrice = '', this.outOfStock = false});

  final String variantId;
  final String name;
  final int quantity;
  final String totalPrice;
  final bool outOfStock;

  factory PosQuoteLine.fromJson(JsonReader r) => PosQuoteLine(variantId: r.text('productVariantId'), name: r.text('productName'), quantity: r.integer('quantity') ?? 0, totalPrice: r.text('totalPrice'), outOfStock: r.flag('itemOutOfStock'));
}

/// The server's answer to "save this cart": the cart id, the bill, the ways to pay. Priced by the server, never by the app.
class PosCartQuote {
  const PosCartQuote({
    this.cartId = '',
    this.cartAmount = 0,
    this.lines = const [],
    this.methods = const [],
    this.bill = const [],
    this.currency = '',
    this.quantity = 0,
    this.storeName = '',
    this.storeAddress = '',
    this.outOfStock = false,
    this.promoCode = '',
    this.promoActive = false,
    this.promoText = '',
  });

  final String cartId;
  final double cartAmount;
  final List<PosQuoteLine> lines;
  final List<PosPaymentMethod> methods;
  final List<PosBillRow> bill;
  final String currency;
  final int quantity;
  final String storeName;
  final String storeAddress;
  final bool outOfStock;
  final String promoCode;
  final bool promoActive;
  final String promoText;

  /// The line to pay: the last bold row of the bill, else the cart amount.
  String get totalText => bill.where((b) => b.bold).lastOrNull?.valueFormatted.trim().isNotEmpty == true ? bill.where((b) => b.bold).last.valueFormatted : '';

  bool lineOutOfStock(String variantId) => lines.any((l) => l.variantId == variantId && l.outOfStock);

  factory PosCartQuote.fromJson(JsonReader root) {
    final d = root.sub('data');
    final receipt = d.sub('receipt');
    return PosCartQuote(
      cartId: d.text('id'),
      cartAmount: d.number('cartAmount') ?? 0,
      lines: d.list('productDetails', PosQuoteLine.fromJson),
      methods: [for (final m in d.list('paymentMethod', PosPaymentMethod.fromJson)) if (m.id.isNotEmpty) m],
      bill: receipt.list('billDetails', PosBillRow.fromJson),
      currency: receipt.text('currency'),
      quantity: receipt.integer('quantity') ?? 0,
      storeName: d.text('storeName'),
      storeAddress: d.text('storeAddress'),
      outOfStock: d.flag('cartOutOfStock'),
      promoCode: d.text('promoCode'),
      promoActive: d.flag('activePromoCode'),
      promoText: d.text('promoCodeText'),
    );
  }
}

/// An offer from the promo list.
class PosPromo {
  const PosPromo({required this.code, this.value = '', this.description = '', this.minAmount = 0, this.valueType = 0, this.maxDiscount = ''});

  final String code;
  final String value;
  final String description;
  final double minAmount;
  final int valueType; // 1 = a percentage, anything else = a fixed amount
  final String maxDiscount;

  bool get isPercent => valueType == 1;

  factory PosPromo.fromJson(JsonReader r) => PosPromo(
    code: r.text('promoCode'),
    value: r.text('promoCodeValue'),
    description: r.text('promoCodeDescription'),
    minAmount: posNum(r.text('orderMinimumAmount')),
    valueType: r.integer('promoCodeValueType') ?? 0,
    maxDiscount: r.text('promoPercentageMaximumDiscount'),
  );
}

/// A registered customer found by name or phone.
class PosCustomerUser {
  const PosCustomerUser({required this.userId, this.name = '', this.phone = '', this.email = ''});

  final String userId;
  final String name;
  final String phone;
  final String email;

  factory PosCustomerUser.fromJson(JsonReader r) => PosCustomerUser(userId: r.text('userId'), name: r.text('name'), phone: r.text('phone'), email: r.text('email'));
}

/// The customer attached to an order. Walk-in = no details.
class PosCustomer {
  const PosCustomer({this.name = '', this.phone = '', this.walkIn = false});

  final String name;
  final String phone;
  final bool walkIn;

  static const walk = PosCustomer(walkIn: true);
}