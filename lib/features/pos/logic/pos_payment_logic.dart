import '../data/pos_checkout_models.dart';
import '../data/pos_sale_models.dart';
import 'pos_shift_logic.dart' show posAmountText, posNum;

enum PayKind { cash, card, upi, other }

/// Jetpack tells the kind of payment from the method's name.
PayKind payKind(String name) {
  final n = name.toLowerCase();
  if (n.contains('cash')) return PayKind.cash;
  if (n.contains('card')) return PayKind.card;
  if (n.contains('upi') || n.contains('qr')) return PayKind.upi;
  return PayKind.other;
}

/// The quick cash buttons.
const kQuickCash = [500, 1000, 2000, 5000];

/// The amount to pay: the last bold row of the bill, else the cart amount.
double grandTotal(PosCartQuote q) {
  final row = q.bill.where((b) => b.bold).lastOrNull;
  final v = row == null ? null : double.tryParse(row.value.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  return v ?? q.cartAmount;
}

/// What goes back to the customer. Jetpack cut it to a whole number; the decimals are kept here.
double changeDue(double received, double total) => received > total ? received - total : 0;

bool cashEnough(double received, double total) => received + 0.005 >= total;

/// "Pay %@ via %@" with its placeholders filled in order. (The server text uses the iOS marker.)
String fillAt(String template, List<String> args) {
  var i = 0;
  return template.replaceAllMapped(RegExp('%@'), (m) => i < args.length ? args[i++] : '');
}

/// The body of "place order". For cash the amount received and the change are sent; for every other method both are empty
/// (Jetpack sent the text "null").
Map<String, Object?> placeOrderBody({
  required String cartId,
  required String methodId,
  required String sessionId,
  required String orderType,
  required PayKind kind,
  double? cashReceived,
  double? change,
  String promoCode = '',
  String customerName = '',
  String customerPhone = '',
}) =>
    {
      'cart_id': cartId,
      'payment_method_id': methodId,
      'pos_session_id': sessionId,
      'pos_order_type': orderType,
      'change_returned': (kind == PayKind.cash && change != null) ? posAmountText(change) : '',
      'cash_received': (kind == PayKind.cash && cashReceived != null) ? posAmountText(cashReceived) : '',
      'promo_code': promoCode,
      'pos_table_number': '',
      'pos_customer_name': customerName,
      'pos_customer_phone': customerPhone,
    };

String digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// The receipt as plain text, for WhatsApp, SMS and e-mail.
String receiptText(PosReceipt r, {required String store, required String thanks, required String orderLabel, String Function(String)? money}) {
  String m(String v) => money == null ? v : money(v);
  final b = StringBuffer()
    ..writeln(store)
    ..writeln('$orderLabel ${r.orderNumber}')
    ..writeln();
  for (final i in r.items) {
    b.writeln('${i.quantity} × ${i.name}${i.variant.isEmpty ? '' : ' (${i.variant})'}  ${m(i.total)}');
    for (final o in i.options) {
      b.writeln('   + ${o.name}');
    }
  }
  b.writeln();
  for (final row in r.bill) {
    b.writeln('${row.name}: ${row.valueFormatted.isNotEmpty ? row.valueFormatted : m(row.value)}');
  }
  b
    ..writeln()
    ..write(thanks);
  return b.toString();
}

/// How much is left to the customer's number: the digits of a phone, or empty.
String contactDigits(PosReceipt r, PosLastSale? sale) => digitsOnly(r.customerPhone.isNotEmpty ? r.customerPhone : (sale?.customerPhone ?? ''));

/// A figure from the server text, for the receipt lines.
double amountOf(String s) => posNum(s);