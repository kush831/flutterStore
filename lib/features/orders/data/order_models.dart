import '../../../core/network/json_reader.dart';

enum PaidState { unknown, paid, unpaid }

class OrderItem {
  const OrderItem({
    required this.id,
    this.number = 0,
    this.items = '',
    this.statusText = '',
    this.time = '',
    this.date = '',
    this.timestamp = 0,
    this.paymentMode = '',
    this.amount = '',
    this.paid = '',
  });

  final int id;
  final int number;
  final String items; // the server's one-line summary ("2 x Paneer Tikka, 1 x Naan")
  final String statusText; // already in the user's language
  final String time;
  final String date;
  final int timestamp;
  final String paymentMode;
  final String amount;
  final String paid;

  /// Unix seconds (a value in milliseconds is accepted too).
  int get timestampSec => timestamp > 1000000000000 ? timestamp ~/ 1000 : timestamp;

  PaidState get paidState {
    switch (paid.trim().toLowerCase()) {
      case '1' || 'true' || 'paid' || 'yes':
        return PaidState.paid;
      case '0' || 'false' || 'unpaid' || 'no':
        return PaidState.unpaid;
      default:
        return PaidState.unknown;
    }
  }

  /// The server sent a readable label (not 0/1): show it as text.
  bool get paidIsLabel => paid.trim().isNotEmpty && paidState == PaidState.unknown;

  /// When a new order runs out of time (same rule as Jetpack: + 27 s grace). null = no countdown.
  DateTime? expiresAt(int expireMinutes) => (timestampSec == 0 || expireMinutes <= 0)
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000 + expireMinutes * 60000 + 27000);

  factory OrderItem.fromJson(JsonReader r) {
    final info = r.sub('info');
    final pay = r.sub('paymentDetails');
    return OrderItem(
      id: info.integer('id') ?? 0,
      number: info.integer('number') ?? 0,
      items: info.text('items'),
      statusText: info.text('statusText'),
      time: info.text('time'),
      date: info.text('orderDate'),
      timestamp: info.integer('orderTimestamp') ?? 0,
      paymentMode: pay.text('paymentMode'),
      amount: pay.text('amount'),
      paid: pay.text('paid'),
    );
  }
}