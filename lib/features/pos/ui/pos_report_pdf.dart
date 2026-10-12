import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/strings/strings_scope.dart';
import '../data/pos_report_models.dart';

/// The analysis as an A4 PDF: the same sections as the screen, as tables. Jetpack's POSAnalyticsPdfGenerator.
Future<void> sharePosAnalyticsPdf(BuildContext context, PosReport r, {required String store, required String periodLabel, required String currency}) async {
  final t = {
    'title': context.str('pos_posanalysisscreen_top_bar_title'),
    'revenue': context.str('pos_posanalysisscreen_revenue_label'),
    'orders': context.str('pos_posanalysisscreen_kpi_orders'),
    'avg': context.str('pos_posanalysisscreen_kpi_avg_ticket'),
    'peak': context.str('pos_posanalysisscreen_peak_hours_title'),
    'peakRevenue': context.str('pos_posanalysisscreen_peak_revenue_label'),
    'category': context.str('pos_posanalysisscreen_category_title'),
    'best': context.str('pos_posanalysisscreen_best_sellers_title'),
    'payment': context.str('pos_posanalysisscreen_payment_title'),
    'staff': context.str('pos_posanalysisscreen_staff_title'),
    'sold': context.str('pos_posdashboardscreen_sold_suffix').trim(),
  };
  final bytes = await buildAnalyticsPdf(r, store: store, periodLabel: periodLabel, t: t);
  await Printing.sharePdf(bytes: bytes, filename: 'analysis-${DateTime.now().millisecondsSinceEpoch}.pdf');
}

Future<Uint8List> buildAnalyticsPdf(PosReport r, {required String store, required String periodLabel, required Map<String, String> t}) async {
  // A font with the rupee sign (and more) is fetched once; offline, the plain font is used and "₹" is left out
  pw.Font? base;
  pw.Font? bold;
  try {
    base = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {}
  String s(String v) => base != null ? v : v.replaceAll('₹', 'Rs ');

  final doc = pw.Document(theme: base != null ? pw.ThemeData.withFont(base: base, bold: bold) : pw.ThemeData());
  pw.Widget h(String text) => pw.Padding(padding: const pw.EdgeInsets.only(top: 16, bottom: 6), child: pw.Text(s(text), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
  pw.Widget table(List<String> head, List<List<String>> rows) => pw.TableHelper.fromTextArray(
    headers: [for (final x in head) s(x)],
    data: [for (final row in rows) [for (final c in row) s(c)]],
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignments: {for (var i = 1; i < head.length; i++) i: pw.Alignment.centerRight, 0: pw.Alignment.centerLeft},
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Text(s(store), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(s('${t['title']} · $periodLabel'), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        h(t['title']!),
        table([t['revenue']!, t['orders']!, t['avg']!], [[r.revenue.revenue, '${r.revenue.orders}', r.revenue.avgTicket], ['', r.revenue.ordersGrowth, r.revenue.avgTicketGrowth].isEmpty ? [] : [r.revenue.revenueGrowth, r.revenue.ordersGrowth, r.revenue.avgTicketGrowth]]),
        if (r.peak.hourly.isNotEmpty) ...[
          h('${t['peak']}${r.peak.peakHour.isEmpty ? '' : '  ·  ${r.peak.peakHour}  (${t['peakRevenue']} ${r.peak.peakRevenue})'}'),
          table(['', t['revenue']!, t['orders']!], [for (final x in r.peak.hourly) [x.label, x.revenue, '${x.orders}']]),
        ],
        if (r.categories.isNotEmpty) ...[h(t['category']!), table(['', t['revenue']!, '%', ''], [for (final c in r.categories) [c.name, c.revenue, c.percentage, c.growth]])],
        if (r.bestItems.isNotEmpty) ...[h(t['best']!), table(['', t['sold']!, t['revenue']!, ''], [for (final i in r.bestItems) [i.name, i.totalSold, i.revenue, i.growth]])],
        if (r.payments.breakdown.isNotEmpty) ...[h('${t['payment']}  ·  ${r.payments.totalAmount}'), table(['', t['orders']!, t['revenue']!, '%'], [for (final p in r.payments.breakdown) [p.name, '${p.orders}', p.amount, p.percentageText]])],
        if (r.staff.isNotEmpty) ...[h(t['staff']!), table(['', t['orders']!, t['avg']!, t['revenue']!], [for (final x in r.staff) [x.name, '${x.orders}', x.avgOrder, x.revenue]])],
      ],
    ),
  );
  return doc.save();
}