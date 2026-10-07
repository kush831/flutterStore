import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/features/orders/data/order_detail_models.dart';
import 'package:apporio_store_30sept/features/orders/data/orders_repository.dart';
import 'package:apporio_store_30sept/features/orders/logic/order_actions.dart';

OrderAction a(String action) => OrderAction(text: action, colour: '', action: action);

void main() {
  test('only buttons the app can run are shown, and never the Call buttons', () {
    final shown = OrderActions.visible([a('ACCEPT'), a('REJECT'), a('CALL_CUSTOMER'), a('SOMETHING_NEW'), a('assign'), a('PICKUP_VERIFICATION')]);
    expect(shown.map((x) => x.action), ['ACCEPT', 'REJECT', 'assign', 'PICKUP_VERIFICATION']);
  });

  test('ASSIGN shows the spinner for both assign flavours', () {
    expect(OrderActions.isBusyFor(OrderActions.autoAssign, 'ASSIGN'), isTrue);
    expect(OrderActions.isBusyFor(OrderActions.manualAssign, 'ASSIGN'), isTrue);
    expect(OrderActions.isBusyFor(OrderActions.accept, 'ASSIGN'), isFalse);
    expect(OrderActions.isBusyFor(null, 'ACCEPT'), isFalse);
  });

  test('the manual assignment payload is the JSON text the API expects', () {
    expect(encodeDriverIds([12, 15]), '[{"id":"12"},{"id":"15"}]');
    expect(encodeDriverIds([]), '[]');
  });

  test('reject is recognised in any case', () {
    expect(OrderActions.isReject(' reject '), isTrue);
    expect(OrderActions.isReject('ACCEPT'), isFalse);
  });
}