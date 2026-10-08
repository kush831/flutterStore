import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';

/// A bar chart. Tap a bar to see its value. The selected bar is solid, the others are lighter.
class BarChartView extends StatefulWidget {
  const BarChartView({super.key, required this.values, required this.labels, required this.format, this.initialSelected = -1, this.height = 190});

  final List<double> values;
  final List<String> labels;
  final String Function(double) format;
  final int initialSelected;
  final double height;

  @override
  State<BarChartView> createState() => _BarChartViewState();
}

class _BarChartViewState extends State<BarChartView> {
  late int _selected = widget.initialSelected;

  @override
  void didUpdateWidget(BarChartView old) {
    super.didUpdateWidget(old);
    if (old.values != widget.values) _selected = widget.initialSelected; // a new period starts on its best bar
  }

  void _pick(double dx, double width) {
    final n = widget.values.length;
    if (n == 0) return;
    final i = (dx / (width / n)).floor().clamp(0, n - 1).toInt();
    setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _pick(d.localPosition.dx, box.maxWidth),
        child: SizedBox(
          width: box.maxWidth,
          height: widget.height,
          child: CustomPaint(
            painter: _BarPainter(
              values: widget.values,
              labels: widget.labels,
              selected: _selected,
              format: widget.format,
              bar: context.primary,
              grid: tk.border,
              text: tk.text3,
              tipBg: tk.text1,
              tipText: tk.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.values, required this.labels, required this.selected, required this.format, required this.bar, required this.grid, required this.text, required this.tipBg, required this.tipText});

  final List<double> values;
  final List<String> labels;
  final int selected;
  final String Function(double) format;
  final Color bar;
  final Color grid;
  final Color text;
  final Color tipBg;
  final Color tipText;

  TextPainter _tp(String s, double size, Color c, {FontWeight w = FontWeight.w500}) =>
      TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: c, fontWeight: w)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');

  @override
  void paint(Canvas canvas, Size size) {
    const top = 34.0; // room for the tooltip
    const bottom = 24.0; // room for the labels
    final plotH = size.height - top - bottom;
    final n = values.length;
    if (n == 0 || plotH <= 0) return;
    final maxV = values.reduce(math.max);
    final slot = size.width / n;
    final barW = math.min(slot * 0.58, 38.0);

    // grid lines
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = top + plotH - plotH * g / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final h = maxV <= 0 ? 0.0 : plotH * (values[i] / maxV);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, top + plotH - h, barW, math.max(h, values[i] > 0 ? 2.0 : 0.0)),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = i == selected ? bar : bar.withValues(alpha: 0.32));

      final label = _tp(i < labels.length ? labels[i] : '', 10.5, i == selected ? bar : text, w: i == selected ? FontWeight.w700 : FontWeight.w500)..layout(maxWidth: slot);
      label.paint(canvas, Offset(cx - label.width / 2, size.height - bottom + 6));
    }

    // the tooltip of the selected bar
    if (selected >= 0 && selected < n) {
      final cx = slot * selected + slot / 2;
      final h = maxV <= 0 ? 0.0 : plotH * (values[selected] / maxV);
      final tip = _tp(format(values[selected]), 12, tipText, w: FontWeight.w700)..layout();
      const padX = 9.0;
      final w = tip.width + padX * 2;
      final left = (cx - w / 2).clamp(0.0, math.max(0.0, size.width - w)).toDouble();
      final y = math.max(2.0, top + plotH - h - 26);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, y, w, 22), const Radius.circular(8)), Paint()..color = tipBg);
      tip.paint(canvas, Offset(left + padX, y + (22 - tip.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.values != values || o.selected != selected || o.bar != bar || o.labels != labels;
}

/// A donut with two shares (in percent). The centre text is drawn by the caller.
class DonutView extends StatelessWidget {
  const DonutView({super.key, required this.first, required this.second, required this.firstColor, required this.secondColor, this.size = 120, this.child});

  final double first;
  final double second;
  final Color firstColor;
  final Color secondColor;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DonutPainter(first, second, firstColor, secondColor, context.tk.sunken),
      child: Center(child: child),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.first, this.second, this.c1, this.c2, this.empty);

  final double first;
  final double second;
  final Color c1;
  final Color c2;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final total = first + second;
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, p(empty));
      return;
    }
    final a = math.pi * 2 * (first / total);
    canvas.drawArc(rect, -math.pi / 2, a, false, p(c1));
    canvas.drawArc(rect, -math.pi / 2 + a, math.pi * 2 - a, false, p(c2));
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.first != first || o.second != second || o.c1 != c1 || o.c2 != c2;
}