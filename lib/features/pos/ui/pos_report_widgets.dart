import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_report_models.dart';
import '../logic/pos_report_logic.dart';

/// A titled card of the report.
class PosReportCard extends StatelessWidget {
  const PosReportCard({super.key, required this.title, this.subtitle, this.trailing, required this.children});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tk.text3)), if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: tk.text3))])),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "+12.5%" in green, "-3%" in red, "0%" in grey.
class GrowthChip extends StatelessWidget {
  const GrowthChip(this.growth, {super.key, this.positive, this.suffix = ''});

  final String growth;
  final bool? positive;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (growth.trim().isEmpty) return const SizedBox.shrink();
    final tk = context.tk;
    final t = trendOf(growth, positive: positive);
    final c = switch (t) { Trend.up => tk.success, Trend.down => tk.danger, Trend.flat => tk.text3 };
    final icon = switch (t) { Trend.up => Icons.trending_up_rounded, Trend.down => Icons.trending_down_rounded, Trend.flat => Icons.trending_flat_rounded };
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: c), const SizedBox(width: 3), Flexible(child: Text('$growth$suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)))]);
  }
}

/// Sales by the hour: a bar for each slot, the peak in the brand color.
class HourlyBars extends StatelessWidget {
  const HourlyBars({super.key, required this.peak});

  final PosPeakHours peak;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final bars = hourlyBars(peak.hourly);
    if (bars.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text(context.str('pos_posanalysisscreen_noDataAvailable'), style: TextStyle(color: tk.text3))));
    final step = bars.length > 12 ? 3 : (bars.length > 8 ? 2 : 1);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Expanded(child: Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: bars[i].fraction < 0.04 ? 0.04 : bars[i].fraction, child: Container(decoration: BoxDecoration(color: isPeakSlot(bars[i].slot, peak.peakHour) ? context.primary : context.primary.withValues(alpha: 0.28), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))))),),
                  const SizedBox(height: 4),
                  SizedBox(height: 14, child: i % step == 0 || isPeakSlot(bars[i].slot, peak.peakHour) ? FittedBox(child: Text(bars[i].slot.label, style: TextStyle(fontSize: 10, color: tk.text3))) : null),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row with a name, a figure and a bar showing its share.
class ShareRow extends StatelessWidget {
  const ShareRow({super.key, required this.name, required this.value, required this.share, this.note, this.trailing});

  final String name;
  final String value;
  final double share; // 0 to 1
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
          ?trailing,
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(50), child: LinearProgressIndicator(value: share, minHeight: 6, backgroundColor: tk.sunken, color: context.primary)),
        if (note != null && note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(note!, style: TextStyle(fontSize: 12, color: tk.text3))),
      ]),
    );
  }
}