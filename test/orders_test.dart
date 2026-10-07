import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/core/network/json_reader.dart';
import 'package:apporio_store_30sept/features/orders/data/order_models.dart';
import 'package:apporio_store_30sept/features/orders/logic/order_tabs.dart';

void main() {
  test('deep-link tabs from Home', () {
    expect(OrderTab.fromParam('new'), OrderTab.newOrders);
    expect(OrderTab.fromParam('ongoing'), OrderTab.preparing);
    expect(OrderTab.fromParam('completed'), OrderTab.completed);
    expect(OrderTab.fromParam('nonsense'), OrderTab.newOrders);
    expect(OrderTab.fromParam(null), OrderTab.newOrders);
  });

  test('status pill colour follows the tab, never the translated text', () {
    expect(OrderTab.preparing.toneFor('ONGOING'), OrderTone.warning);
    expect(OrderTab.preparing.toneFor('ONTHEWAY'), OrderTone.info);
    expect(OrderTab.completed.toneFor('COMPLETED'), OrderTone.success);
    expect(OrderTab.rejected.toneFor('REJECTED'), OrderTone.danger);
  });

  test('an order parses from the API shape (snake_case, loose numbers)', () {
    final o = OrderItem.fromJson(JsonReader({
      'info': {'id': 77, 'number': '1042', 'items': '2 x Paneer Tikka', 'status_text': 'New Order', 'time': '10:42 AM', 'order_date': '07 Oct', 'order_timestamp': 1790000000},
      'payment_details': {'payment_mode': 'UPI', 'amount': '480.00', 'paid': '1'},
    }));
    expect([o.id, o.number], [77, 1042]);
    expect(o.paymentMode, 'UPI');
    expect(o.paidState, PaidState.paid);
    expect(o.paidIsLabel, isFalse);
  });

  test('the expiry deadline adds the minutes and the 27 s grace', () {
    const o = OrderItem(id: 1, timestamp: 1000000000);
    expect(o.expiresAt(10), DateTime.fromMillisecondsSinceEpoch(1000000000 * 1000 + 10 * 60000 + 27000));
    expect(o.expiresAt(0), isNull);
    expect(const OrderItem(id: 2).expiresAt(10), isNull);
  });

  test('a readable paid label is shown as text', () {
    expect(const OrderItem(id: 1, paid: 'Paid').paidIsLabel, isTrue);
    expect(const OrderItem(id: 1, paid: '0').paidState, PaidState.unpaid);
  });
}