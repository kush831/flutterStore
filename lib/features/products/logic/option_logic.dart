import 'dart:convert';

import '../data/product_detail_models.dart';

/// `arr_option` of save-options: the TICKED options as JSON text, e.g. [{"id":"12","amount":"5"}].
/// A blank amount is sent as "0" (Jetpack).
String optionsPayload(Iterable<MappedOption> options) => jsonEncode([
  for (final o in options)
    if (o.checked) {'id': o.id, 'amount': o.amount.trim().isEmpty ? '0' : o.amount.trim()},
]);

/// A ticked option that carries a price needs a number there (blank is allowed: it is sent as 0).
bool amountValid(MappedOption o) {
  if (!o.checked || !o.showAmountField) return true;
  final t = o.amount.trim();
  if (t.isEmpty) return true;
  final n = double.tryParse(t);
  return n != null && n >= 0;
}