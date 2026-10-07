import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/core/network/json_reader.dart';
import 'package:apporio_store_30sept/features/orders/data/order_detail_models.dart';

void main() {
  final sample = JsonReader({
    'result': '1',
    'data': {
      'details': {'id': 77, 'number': '1042', 'status': 1, 'total_items': '3', 'status_text': 'New Order', 'order_time': '10:42 AM', 'deliver_on_formatted': 'Today 11:30'},
      'product_details': [
        {
          'name': 'Paneer Tikka',
          'product_variant': 'Half',
          'value': '₹ 360',
          'bold': false,
          'items': 2,
          'discount': '0.00',
          'arr_options': [
            {'id': '1', 'option_name': 'Extra cheese', 'amount': '₹ 20'},
          ],
        },
      ],
      'bill_details': [
        {'name': 'Delivery fee', 'value': '₹ 40', 'bold': false},
        {'name': 'Total', 'value': '₹ 480', 'bold': true},
      ],
      'payment_details': {'paid_status': 'Paid', 'payment_mode': 'UPI', 'amount': '480', 'currency': '₹'},
      'customer_details': {'customer_name': 'John', 'customer_phone': '98', 'drop_location': 'Sector 62'},
      'driver_details': {'driver_name': '', 'driver_phone': '', 'driver_rating': ''},
      'action_buttons': [
        {'button_text': 'Accept', 'button_text_colour': '#fff', 'button_action': 'ACCEPT'},
      ],
      'order_status_holder': [
        {'status_text': 'Placed', 'status_time': '1790000000', 'tick_icon': 'https://x/y.png'},
        {'status_text': 'Accepted', 'status_time': '', 'tick_icon': ''},
      ],
      'instruction_options': ['Less spicy'],
      'order_process_otp': '4821',
    },
  });

  test('the whole order parses from the API shape', () {
    final d = OrderDetail.fromJson(sample);
    expect([d.id, d.number, d.totalItems], [77, 1042, 3]);
    expect(d.deliverOn, 'Today 11:30');
    expect(d.lines.single.options.single.name, 'Extra cheese');
    expect(d.lines.single.quantity, 2);
    expect(d.bill.last.bold, isTrue);
    expect(d.payment.paidStatus, 'Paid');
    expect(d.actions.single.action, 'ACCEPT');
    expect(d.instructionOptions, ['Less spicy']);
  });

  test('an empty driver and an empty discount are hidden', () {
    final d = OrderDetail.fromJson(sample);
    expect(d.driver, isNull);
    expect(d.customer, isNotNull);
    expect(d.lines.single.hasDiscount, isFalse);
    expect(const OrderLine(name: 'x', discount: '₹ 20').hasDiscount, isTrue);
  });

  test('the timeline knows which steps happened', () {
    final d = OrderDetail.fromJson(sample);
    expect(d.timeline.map((s) => s.done), [true, false]);
    expect(d.timeline.first.at, DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000));
    expect(d.timeline.last.at, isNull);
  });
}