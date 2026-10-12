import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/pos_sale_models.dart';

/// The words on the receipt (already translated by the caller).
class ReceiptLabels {
  const ReceiptLabels({required this.title, required this.receiptNo, required this.orderNo, required this.date, required this.cashier, required this.type, required this.customer, required this.colItem, required this.colQty, required this.colAmount, required this.paidVia, required this.cashTendered, required this.change, required this.thanks, required this.noReturns});

  final String title;
  final String receiptNo;
  final String orderNo;
  final String date;
  final String cashier;
  final String type;
  final String customer;
  final String colItem;
  final String colQty;
  final String colAmount;
  final String paidVia;
  final String cashTendered;
  final String change;
  final String thanks;
  final String noReturns;
}

/// The receipt as an 80 mm roll, with the store's own name and phone (Jetpack's PDF had a restaurant's name written into the code).
/// [money] formats a figure (the receipt rows use it for the item prices).
Future<Uint8List> buildReceiptPdf(
    PosReceipt r, {
      required String store,
      String phone = '',
      required ReceiptLabels l,
      required String Function(String) money,
      PosLastSale? sale,
      String Function(double)? cash,
    }) async {
  // A font that has the rupee sign (and more) is fetched once; offline, the plain font is used and "₹" is left out
  pw.Font? base;
  pw.Font? bold;
  try {
    base = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {}
  final theme = base != null ? pw.ThemeData.withFont(base: base, bold: bold) : pw.ThemeData();
  String safe(String s) => base != null ? s : s.replaceAll('₹', 'Rs ');

  const small = pw.TextStyle(fontSize: 8.5);
  final strong = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);

  pw.Widget kv(String k, String v, {pw.TextStyle? style}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Expanded(child: pw.Text(safe(k), style: style ?? small)), pw.SizedBox(width: 6), pw.Text(safe(v), style: style ?? small)]));
  pw.Widget rule() => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed));

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(child: pw.Text(safe(store), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
          if (phone.isNotEmpty) pw.Center(child: pw.Text(safe(phone), style: small)),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(safe(l.title), style: strong)),
          rule(),
          kv(l.receiptNo, r.orderId),
          kv(l.orderNo, r.orderNumber),
          if (r.date.isNotEmpty) kv(l.date, r.date),
          if (r.cashier.isNotEmpty) kv(l.cashier, r.cashier),
          if (r.serviceType.isNotEmpty || r.orderType.isNotEmpty) kv(l.type, r.serviceType.isNotEmpty ? r.serviceType : r.orderType),
          if (r.customerName.isNotEmpty) kv(l.customer, r.customerName),
          rule(),
          pw.Row(children: [pw.Expanded(child: pw.Text(safe(l.colItem), style: strong)), pw.SizedBox(width: 28, child: pw.Text(safe(l.colQty), style: strong, textAlign: pw.TextAlign.center)), pw.SizedBox(width: 56, child: pw.Text(safe(l.colAmount), style: strong, textAlign: pw.TextAlign.right))]),
          pw.SizedBox(height: 3),
          for (final i in r.items)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Expanded(child: pw.Text(safe(i.name), style: small)), pw.SizedBox(width: 28, child: pw.Text('${i.quantity}', style: small, textAlign: pw.TextAlign.center)), pw.SizedBox(width: 56, child: pw.Text(safe(money(i.total)), style: small, textAlign: pw.TextAlign.right))]),
                if (i.variant.isNotEmpty) pw.Text(safe(i.variant), style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                for (final o in i.options) pw.Text(safe('+ ${o.name}'), style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ]),
            ),
          rule(),
          for (final b in r.bill) kv(b.name, b.valueFormatted.isNotEmpty ? b.valueFormatted : money(b.value), style: b.bold ? strong : small),
          rule(),
          if (r.paymentMethod.isNotEmpty) kv(l.paidVia, r.paymentMethod),
          if (sale?.cashReceived != null && cash != null) kv(l.cashTendered, cash(sale!.cashReceived!)),
          if (sale?.changeDue != null && cash != null) kv(l.change, cash(sale!.changeDue!)),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(safe(l.thanks), style: strong, textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text(safe(l.noReturns), style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700), textAlign: pw.TextAlign.center)),
        ],
      ),
    ),
  );
  return doc.save();
}