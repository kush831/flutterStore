import 'package:flutter/material.dart';

import '../strings/strings_scope.dart';
import '../time/period_range.dart';
import 'design_tokens.dart';
import 'selected_scroll_row.dart';

/// The period chips: Today · This Week · This Month · All · Custom (a date-range picker).
class PeriodFilter extends StatelessWidget {
  const PeriodFilter({super.key, required this.value, required this.onChanged, this.horizontalPadding = 0});

  final PeriodRange value;
  final ValueChanged<PeriodRange> onChanged;
  final double horizontalPadding;

  static const _order = [PeriodPreset.today, PeriodPreset.week, PeriodPreset.month, PeriodPreset.all, PeriodPreset.custom];

  static String _labelKey(PeriodPreset p) => switch (p) {
    PeriodPreset.today => 'main_storedashboard_sales_today_title',
    PeriodPreset.week => 'main_storedashboard_sales_week_title',
    PeriodPreset.month => 'main_storedashboard_sales_month_title',
    PeriodPreset.all => 'products_products_all_category',
    PeriodPreset.custom => 'storedetails_storeprofile_custom',
  };

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: (value.preset == PeriodPreset.custom && value.start != null && value.end != null) ? DateTimeRange(start: value.start!, end: value.end!) : null,
      helpText: context.str('pos_posordersfiltersheetscreen_date_range'),
      saveText: context.str('common_allscreen_ok_button'),
    );
    if (picked != null) onChanged(PeriodRange.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    final loc = MaterialLocalizations.of(context);

    String label(PeriodPreset p) {
      if (p == PeriodPreset.custom && value.preset == PeriodPreset.custom && value.start != null && value.end != null) {
        return '${loc.formatShortDate(value.start!)} – ${loc.formatShortDate(value.end!)}';
      }
      return context.str(_labelKey(p));
    }

    return SizedBox(
      height: 56,
      child: SelectedScrollRow(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
        selectedIndex: _order.indexOf(value.preset),
        children: [
          for (final p in _order)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () => p == PeriodPreset.custom ? _pickCustom(context) : onChanged(PeriodRange.preset(p, DateTime.now(), firstDayOfWeek: loc.firstDayOfWeekIndex)),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == value.preset ? primary : tk.surface,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: p == value.preset ? primary : tk.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (p == PeriodPreset.custom) ...[Icon(Icons.date_range_rounded, size: 16, color: p == value.preset ? Colors.white : tk.text2), const SizedBox(width: 6)],
                    Text(label(p), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p == value.preset ? Colors.white : tk.text2)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}