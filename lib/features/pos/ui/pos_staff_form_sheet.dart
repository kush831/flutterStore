import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_shift_repository.dart' show posBusinessIdProvider;
import '../data/pos_staff_models.dart';
import '../data/pos_staff_repository.dart';
import '../logic/pos_staff_logic.dart';
import '../logic/pos_staff_providers.dart';
import 'pos_widgets.dart';

/// Add a staff member (detail == null) or edit one. Returns true when it was saved.
Future<bool?> showStaffForm(BuildContext context, {PosStaffDetail? detail, List<PosRoleSummary> roles = const []}) {
  final body = _StaffForm(detail: detail, roles: roles);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500, maxHeight: 760), child: body)));
  }
  return showModalBottomSheet<bool>(context: context, isScrollControlled: true, isDismissible: false, useSafeArea: true, builder: (_) => body);
}

class _StaffForm extends ConsumerStatefulWidget {
  const _StaffForm({this.detail, this.roles = const []});

  final PosStaffDetail? detail;
  final List<PosRoleSummary> roles;

  @override
  ConsumerState<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends ConsumerState<_StaffForm> {
  bool get _isEdit => widget.detail != null;

  late final _first = TextEditingController(text: widget.detail?.nameParts.first ?? '');
  late final _last = TextEditingController(text: widget.detail?.nameParts.last ?? '');
  late final _phone = TextEditingController(text: widget.detail?.phone.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
  final _pin = TextEditingController();
  String _roleId = '';
  late String _start = _valid(widget.detail?.shiftStart) ?? kDefaultShiftStart;
  late String _end = _valid(widget.detail?.shiftEnd) ?? kDefaultShiftEnd;
  Set<StaffField> _errors = {};
  String? _serverError;
  bool _busy = false;

  String? _valid(String? s) => (s != null && parseShift(s) != null) ? shiftText(parseShift(s)!) : null;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final t = parseShift(start ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: t, helpText: context.str(start ? 'pos_posstaffscreen_shift_start' : 'pos_posstaffscreen_shift_end'));
    if (picked != null && mounted) setState(() => start ? _start = shiftText(picked) : _end = shiftText(picked));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final errors = validateStaff(first: _first.text, phone: _phone.text, pin: _pin.text, roleId: _roleId, isEdit: _isEdit);
    setState(() {
      _errors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    final bid = ref.read(posBusinessIdProvider);
    final repo = ref.read(posStaffRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(updateStaffBody(businessId: bid, staffId: widget.detail!.staffId, first: _first.text, last: _last.text, phone: _phone.text, pin: _pin.text, shiftStart: _start, shiftEnd: _end));
      } else {
        final role = widget.roles.firstWhere((r) => r.id == _roleId);
        await repo.add(addStaffBody(businessId: bid, first: _first.text, last: _last.text, phone: _phone.text, pin: _pin.text, role: role, shiftStart: _start, shiftEnd: _end));
      }
      ref.invalidate(posStaffSummaryProvider);
      ref.invalidate(posStaffListProvider);
      if (_isEdit) ref.invalidate(posStaffDetailProvider(widget.detail!.staffId));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 14), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3)));
    Widget timeBox(String key, String value, bool start) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label(key),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: _busy ? null : () => _pick(start),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
            child: Row(children: [Icon(Icons.access_time_rounded, size: 18, color: tk.text3), const SizedBox(width: 8), Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))]),
          ),
        ),
      ]),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(context.str(_isEdit ? 'pos_posstaffscreen_edit_staff' : 'pos_posstaffscreen_add_staff_member'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 14), child: TextField(controller: _first, enabled: !_busy, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() => _errors = {..._errors}..remove(StaffField.firstName)), decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_first_name_placeholder'), errorText: _errors.contains(StaffField.firstName) ? ' ' : null)))),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 14), child: TextField(controller: _last, enabled: !_busy, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_last_name_placeholder'))))),
              ]),
              label('pos_posstaffscreen_phone_number'),
              TextField(controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() => _errors = {..._errors}..remove(StaffField.phone)), decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_enter_phone_placeholder'), errorText: _errors.contains(StaffField.phone) ? ' ' : null)),
              if (!_isEdit) label('pos_posstaffscreen_pin_label') else const SizedBox(height: 14),
              TextField(
                controller: _pin,
                enabled: !_busy,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                onChanged: (_) => setState(() => _errors = {..._errors}..remove(StaffField.pin)),
                decoration: InputDecoration(hintText: _isEdit ? context.str('pos_posstaffscreen_new_pin_optional_placeholder') : '••••', counterText: '', errorText: _errors.contains(StaffField.pin) ? ' ' : null),
              ),
              if (!_isEdit) ...[
                label('pos_posstaffscreen_select_role'),
                if (widget.roles.isEmpty)
                  Text(context.str('pos_posstaffscreen_no_roles_found'), style: TextStyle(color: tk.text3))
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final r in widget.roles) ChoiceChip(label: Text(r.name), selected: _roleId == r.id, onSelected: _busy ? null : (_) => setState(() { _roleId = r.id; _errors = {..._errors}..remove(StaffField.role); }))]),
                if (_errors.contains(StaffField.role)) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.str('pos_posstaffscreen_select_role'), style: TextStyle(fontSize: 12, color: tk.danger))),
              ],
              Row(children: [timeBox('pos_posstaffscreen_shift_start', _start, true), const SizedBox(width: 10), timeBox('pos_posstaffscreen_shift_end', _end, false)]),
              if (_serverError != null) ...[const SizedBox(height: 14), PosErrorBox(_serverError!)],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_posstaffscreen_cancel')))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(onPressed: _busy ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str(_busy ? (_isEdit ? 'pos_posstaffscreen_saving' : 'pos_posstaffscreen_adding') : (_isEdit ? 'pos_posstaffscreen_save_changes' : 'pos_posstaffscreen_add_staff_member'))))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}