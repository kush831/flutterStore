import '../../../core/network/json_reader.dart';

// ── wallet ───────────────────────────────────────────────────────────────────

class WalletEntry {
  const WalletEntry({this.type = '', this.paymentMode = '', this.amount = '', this.narration = '', this.on = ''});

  final String type; // "Credit" / "Debit" as the server writes it
  final String paymentMode;
  final String amount;
  final String narration;
  final String on; // the date as the server wrote it

  /// Jetpack: type == "Debit". An amount that starts with "-" is a debit too.
  bool get debit => type.trim().toLowerCase() == 'debit' || amount.trim().startsWith('-');

  /// The amount without its sign: the sign is drawn from [debit].
  String get magnitude => amount.trim().replaceFirst(RegExp(r'^[-+]\s*'), '');

  factory WalletEntry.fromJson(JsonReader r) => WalletEntry(
    type: r.text('transactionType'),
    paymentMode: r.text('paymentMode'),
    amount: r.text('amount'),
    narration: r.text('narration'),
    on: r.text('transactionOn'),
  );
}

class WalletPage {
  const WalletPage({required this.balance, required this.entries, required this.next});

  final String balance; // total_amount
  final List<WalletEntry> entries;
  final int? next;

  factory WalletPage.fromJson(JsonReader root, int page, int? Function(int page, String? nextUrl, bool gotItems) nextPageOf) {
    final d = root.sub('data');
    final entries = d.list('responseData', WalletEntry.fromJson);
    return WalletPage(balance: d.text('totalAmount'), entries: entries, next: nextPageOf(page, d.str('nextPageUrl'), entries.isNotEmpty));
  }
}

// ── cashout ──────────────────────────────────────────────────────────────────

enum CashoutTone { pending, approved, rejected, neutral }

/// Jetpack matches the English words "Pending" / "Approved" / "Success" and paints everything else red.
/// Here an unknown (for example translated) status is neutral.
CashoutTone cashoutTone(String status) {
  final s = status.trim().toLowerCase();
  if (s.isEmpty) return CashoutTone.neutral;
  if (s.contains('pend')) return CashoutTone.pending;
  if (RegExp(r'approv|success|complet|paid').hasMatch(s)) return CashoutTone.approved;
  if (RegExp(r'reject|declin|fail|cancel|denied').hasMatch(s)) return CashoutTone.rejected;
  return CashoutTone.neutral;
}

class CashoutEntry {
  const CashoutEntry({this.amount = '', this.status = '', this.actionBy = '', this.transactionId = '', this.comment = ''});

  final String amount;
  final String status;
  final String actionBy;
  final String transactionId;
  final String comment;

  CashoutTone get tone => cashoutTone(status);

  factory CashoutEntry.fromJson(JsonReader r) => CashoutEntry(
    amount: r.text('amount'),
    status: r.text('status'),
    actionBy: r.text('actionBy'),
    transactionId: r.text('transactionId'),
    comment: r.text('comment'),
  );
}

class CashoutPage {
  const CashoutPage({required this.balance, required this.entries, required this.next});

  final String balance; // total_amount: the available balance
  final List<CashoutEntry> entries;
  final int? next;

  factory CashoutPage.fromJson(JsonReader root, int page, int? Function(int page, String? nextUrl, bool gotItems) nextPageOf) {
    final d = root.sub('data');
    final entries = d.list('responseData', CashoutEntry.fromJson);
    return CashoutPage(balance: d.text('totalAmount'), entries: entries, next: nextPageOf(page, d.str('nextPageUrl'), entries.isNotEmpty));
  }
}

/// The only check done before the request: a number above zero. The server decides if it exceeds the balance.
/// Returns the key of the text to show, or null when the amount is fine.
String? validateCashoutAmount(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'financialsmodule_financialsmodule_cashout_history_enterAmountToWithdraw';
  final n = double.tryParse(t);
  if (n == null || n <= 0) return 'products_addproductscreen_preparation_time_enterValidNumber';
  return null;
}