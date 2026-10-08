import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../logic/store_logic.dart';
import '../logic/store_providers.dart';

class StoreTimingsScreen extends ConsumerStatefulWidget {
  const StoreTimingsScreen({super.key});

  @override
  ConsumerState<StoreTimingsScreen> createState() => _StoreTimingsScreenState();
}

class _StoreTimingsScreenState extends ConsumerState<StoreTimingsScreen> {
  List<DaySchedule> _days = const [];
  String _saved = ''; // what the server has, to know whether anything changed
  bool _initialized = false;
  bool _saving = false;

  bool get _dirty => timingFields(_days).toString() != _saved;

  void _init(StoreProfile p) {
    _days = p.days;
    _saved = timingFields(_days).toString();
    _initialized = true;
  }

  void _setDay(int index, DaySchedule day) => setState(() => _days = [for (var i = 0; i < _days.length; i++) i == index ? day : _days[i]]);

  Future<void> _pickTime(int index, {required bool open}) async {
    final d = _days[index];
    final t = splitTime(open ? d.open : d.close);
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    if (picked == null || !mounted) return;
    final value = joinTime(picked.hour, picked.minute);
    _setDay(index, open ? d.copyWith(open: value) : d.copyWith(close: value));
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      final message = await ref.read(storeRepositoryProvider).saveTimings(_days);
      if (!mounted) return;
      ref.invalidate(storeProfileProvider);
      ref.read(dashboardProvider.notifier).refresh();
      setState(() {
        _saving = false;
        _saved = timingFields(_days).toString(); // nothing left to save
      });
      showAppSnack(context, message.isEmpty ? context.str('common_allscreen_savedSuccessfully') : message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final async = ref.watch(storeProfileProvider);
    final p = async.value;
    if (p != null && !_initialized && !async.isLoading) _init(p);
    final ready = p != null && _initialized;

    final saveButton = FilledButton(
      onPressed: (ready && _dirty && !_saving) ? _save : null,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      child: _saving
          ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
          : Text(context.str('storedetails_storetimeslots_save_changes_button')),
    );

    Widget shortcut(String key, bool selected, VoidCallback onTap) => FilterChip(
      label: Text(context.str(key)),
      selected: selected,
      onSelected: _saving ? null : (_) => onTap(),
      showCheckmark: true,
    );

    final Widget content;
    if (ready) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.str('storedetails_storetimeslots_operating_hours_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 4),
          Text(context.str('storedetails_storetimeslots_operating_hours_message'), style: TextStyle(color: tk.text2, height: 1.4)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            shortcut('storedetails_storetimeslots_selectAll', allDaysSelected(_days), () => setState(() => _days = selectAllDays(_days, !allDaysSelected(_days)))),
            shortcut('storedetails_storetimeslots_weekdays_only_button', onlyWeekdaysSelected(_days), () => setState(() => _days = onlyWeekdaysSelected(_days) ? selectAllDays(_days, false) : weekdaysOnly(_days))),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final two = box.maxWidth >= 640;
            final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < _days.length; i++)
                  SizedBox(
                    width: w,
                    child: _DayCard(
                      day: _days[i],
                      enabled: !_saving,
                      onToggle: (v) => _setDay(i, _days[i].copyWith(enabled: v)),
                      onPickOpen: () => _pickTime(i, open: true),
                      onPickClose: () => _pickTime(i, open: false),
                    ),
                  ),
              ],
            );
          }),
        ],
      );
    } else if (async.hasError && p == null) {
      content = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
          const SizedBox(height: 10),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(storeProfileProvider), child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      content = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 90, radius: 16), SizedBox(height: 12), SkeletonBox(height: 90, radius: 16), SizedBox(height: 12), SkeletonBox(height: 90, radius: 16)]));
    }

    return SubPage(
      title: context.str('storedetails_storetimeslots_title'),
      fallbackRoute: Routes.storeProfile,
      actions: [if (!compact) saveButton],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ListView(padding: EdgeInsets.fromLTRB(compact ? 16 : 0, 12, compact ? 16 : 0, 24), children: [content])),
          if (compact)
            Container(
              decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
              child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: SizedBox(width: double.infinity, child: saveButton))),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.enabled, required this.onToggle, required this.onPickOpen, required this.onPickClose});

  final DaySchedule day;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final loc = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String show(String hhmm) {
      final t = splitTime(hhmm);
      return loc.formatTimeOfDay(TimeOfDay(hour: t.hour, minute: t.minute), alwaysUse24HourFormat: h24);
    }

    Widget timeChip(String labelKey, String value, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str(labelKey), style: TextStyle(fontSize: 11.5, color: tk.text3)),
            const SizedBox(height: 2),
            Row(children: [Expanded(child: Text(show(value), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))), Icon(Icons.access_time_rounded, size: 16, color: tk.text3)]),
          ]),
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(day.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
                  Text(context.str(day.enabled ? 'storedetails_storetimeslots_open' : 'storedetails_storetimeslots_closed'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: day.enabled ? tk.success : tk.danger)),
                ]),
              ),
              Switch(value: day.enabled, onChanged: enabled ? onToggle : null),
            ]),
            if (day.enabled) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(children: [
                  timeChip('storedetails_storetimeslots_open_time_value', day.open, onPickOpen),
                  const SizedBox(width: 10),
                  timeChip('storedetails_storetimeslots_close_time_value', day.close, onPickClose),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}