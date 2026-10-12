
import 'package:flutter/widgets.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_sale_models.dart';
import '../logic/pos_payment_logic.dart';
import '../logic/pos_shift_logic.dart';
import 'receipt_pdf.dart';
import 'dart:typed_data';

/// What a receipt can be done with: share the PDF, print it, or send it as text.
class PosReceiptActions {
  PosReceiptActions(this.context, {required this.receipt, required this.store, required this.phone, required this.currency, this.sale});

  final BuildContext context;
  final PosReceipt receipt;
  final String store;
  final String phone;
  final String currency;
  final PosLastSale? sale;

  String _money(String v) => money(currency, v);

  ReceiptLabels get _labels => ReceiptLabels(
    title: context.str('pos_posreceiptscreen_title'),
    receiptNo: context.str('pos_posreceiptscreen_label_receipt_no'),
    orderNo: context.str('pos_posreceiptscreen_label_order_number'),
    date: context.str('pos_posreceiptscreen_date'),
    cashier: context.str('pos_posreceiptscreen_label_cashier'),
    type: context.str('pos_posreceiptscreen_label_type'),
    customer: context.str('pos_receipt_customer'),
    colItem: context.str('pos_posreceiptscreen_col_item'),
    colQty: context.str('pos_posreceiptscreen_col_qty'),
    colAmount: context.str('pos_posreceiptscreen_col_amount'),
    paidVia: context.str('pos_posreceiptscreen_label_paid_via'),
    cashTendered: context.str('pos_posreceiptscreen_label_cash_tendered'),
    change: context.str('pos_posreceiptscreen_label_change'),
    thanks: context.str('pos_posreceiptscreen_thank_order'),
    noReturns: context.str('pos_posreceiptscreen_no_returns_note'),
  );

  Future<List<int>> _pdf() => buildReceiptPdf(receipt, store: store, phone: phone, l: _labels, money: _money, sale: sale, cash: (v) => money(currency, posAmountText(v)));

  String get _name => 'receipt-${receipt.orderNumber.isEmpty ? receipt.orderId : receipt.orderNumber}';

  /// The system share sheet with the PDF (WhatsApp, e-mail, Drive …). In a browser the file is downloaded.
  Future<void> share() async => Printing.sharePdf(bytes: Uint8List.fromList(await _pdf()), filename: '$_name.pdf');

  /// The system print dialog.
  Future<void> print() async => Printing.layoutPdf(name: _name, onLayout: (_) async => Uint8List.fromList(await _pdf()));

  String get _text => receiptText(receipt, store: store, thanks: context.str('pos_posreceiptscreen_thank_order'), orderLabel: context.str('pos_posreceiptscreen_label_order_number'), money: _money);

  String get _digits => contactDigits(receipt, sale);

  Future<bool> _open(Uri u) async {
    try {
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// A text message with the receipt. Returns false when no app could open it.
  Future<bool> whatsapp() => _open(Uri.https('wa.me', _digits.isEmpty ? '' : '/$_digits', {'text': _text}));

  Future<bool> sms() => _open(Uri(scheme: 'sms', path: _digits.isEmpty ? '' : '+$_digits', queryParameters: {'body': _text}));

  Future<bool> email() => _open(Uri(scheme: 'mailto', queryParameters: {'subject': '${context.str('pos_posreceiptscreen_title')} ${receipt.orderNumber}', 'body': _text}));
}