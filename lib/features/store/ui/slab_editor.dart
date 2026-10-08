import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/media/image_picking.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/slab_models.dart';
import '../data/slabs_repository.dart';
import '../logic/slab_logic.dart';
import '../logic/store_logic.dart' show joinTime, splitTime;

class SlabResult {
  const SlabResult({required this.deleted, required this.message});

  final bool deleted;
  final String message;
}

/// Add (slab == null) or edit. Returns what happened, or null when closed.
Future<SlabResult?> showSlabEditor(BuildContext context, {AvailabilitySlab? slab}) {
  final editor = SlabEditor(slab: slab);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<SlabResult>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720), child: editor)));
  }
  return showModalBottomSheet<SlabResult>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

Future<bool> confirmDeleteSlab(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, size: 36, color: ctx.tk.danger),
      title: Text(ctx.str('products_productdetail_delete_button')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(ctx.str('storedetails_storeprofile_delete_confirmationMessage'), textAlign: TextAlign.center),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('products_productdetail_delete_button'))),
      ],
    ),
  );
  return ok == true;
}

class SlabEditor extends ConsumerStatefulWidget {
  const SlabEditor({super.key, this.slab});

  final AvailabilitySlab? slab;

  @override
  ConsumerState<SlabEditor> createState() => _SlabEditorState();
}

class _SlabEditorState extends ConsumerState<SlabEditor> {
  bool get _isNew => widget.slab == null;

  late SlabForm _form = _isNew ? const SlabForm() : SlabForm.fromSlab(widget.slab!);
  late final _name = TextEditingController(text: _form.name);
  late final _priority = TextEditingController(text: _form.priority);
  late final _price = TextEditingController(text: _form.price);

  Map<SlabField, String> _errors = {};
  String? _serverError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _priority.dispose();
    _price.dispose();
    super.dispose();
  }

  SlabForm _collect() => _form.copyWith(name: _name.text, priority: _priority.text, price: _price.text);

  void _clear(SlabField f) {
    if (_errors.containsKey(f)) setState(() => _errors = {..._errors}..remove(f));
  }

  Future<void> _pickImage() async {
    final photo = await pickPhoto(context);
    if (photo != null && mounted) setState(() => _form = _collect().copyWith(photo: photo));
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _form.start : _form.end;
    final t = current.isEmpty ? (hour: start ? 8 : 12, minute: 0) : splitTime(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
      helpText: context.str(start ? 'storedetails_storeprofile_selectStartTime' : 'storedetails_storeprofile_selectEndTime'),
    );
    if (picked == null || !mounted) return;
    final value = joinTime(picked.hour, picked.minute);
    setState(() => _form = start ? _collect().copyWith(start: value) : _collect().copyWith(end: value));
    _clear(start ? SlabField.start : SlabField.end);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final f = _collect();
    final errors = validateSlab(f);
    setState(() {
      _form = f;
      _errors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      final message = await ref.read(slabsRepositoryProvider).saveSlab(widget.slab?.id, f);
      if (!mounted) return;
      Navigator.pop(context, SlabResult(deleted: false, message: message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = errorText(e, ref.read(stringsProvider)); // inside the editor: a snackbar would hide behind it
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirmDeleteSlab(context, widget.slab!.name) || !mounted) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      final message = await ref.read(slabsRepositoryProvider).deleteSlab(widget.slab!.id);
      if (!mounted) return;
      Navigator.pop(context, SlabResult(deleted: true, message: message));
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
    final f = _form;
    final loc = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String show(String hhmm) {
      final t = splitTime(hhmm);
      return loc.formatTimeOfDay(TimeOfDay(hour: t.hour, minute: t.minute), alwaysUse24HourFormat: h24);
    }

    String? err(SlabField k) => _errors[k] == null ? null : context.str(_errors[k]!);

    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)));

    Widget timeBox({required String labelKey, required String hintKey, required String value, required SlabField field, required bool enabled, required VoidCallback onTap}) {
      final error = err(field);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(labelKey),
          InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: (enabled && !_busy) ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: enabled ? tk.surface : tk.sunken,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: error != null ? tk.danger : tk.border, width: error != null ? 1.5 : 1),
              ),
              child: Row(children: [
                Expanded(child: Text(value.isEmpty ? context.str(hintKey) : show(value), style: TextStyle(color: value.isEmpty ? tk.text3 : (enabled ? tk.text1 : tk.text2)))),
                Icon(enabled ? Icons.access_time_rounded : Icons.lock_outline_rounded, size: 18, color: tk.text3),
              ]),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(error, style: TextStyle(fontSize: 12.5, color: tk.danger))),
        ],
      );
    }

    Widget switchTile(String titleKey, String subtitleKey, bool value, bool enabled, ValueChanged<bool> onChanged) => Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str(titleKey), style: TextStyle(fontWeight: FontWeight.w700, color: enabled ? tk.text1 : tk.text3)),
            Text(context.str(subtitleKey), style: TextStyle(fontSize: 12.5, color: tk.text2)),
          ]),
        ),
        Switch(value: value, onChanged: (enabled && !_busy) ? onChanged : null),
      ]),
    );

    final image = f.photo != null
        ? Image.memory(f.photo!.bytes, fit: BoxFit.cover)
        : (f.imageUrl.isEmpty ? null : CachedNetworkImage(imageUrl: f.imageUrl, fit: BoxFit.cover, memCacheWidth: 700, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken)));

    final timesLocked = f.custom; // a custom-price slab has no hours

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_isNew ? Icons.add_rounded : Icons.edit_rounded, color: context.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.str(_isNew ? 'storedetails_storeprofile_AddTimeSlab' : 'storedetails_storeprofile_editTimeSlab'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              label('storedetails_storeprofile_slabImage'),
              InkWell(
                borderRadius: BorderRadius.circular(Radii.lg),
                onTap: _busy ? null : _pickImage,
                child: Container(
                  height: 120,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
                  child: image != null
                      ? Stack(fit: StackFit.expand, children: [
                    image,
                    PositionedDirectional(end: 8, bottom: 8, child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white))),
                  ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: tk.text3),
                    const SizedBox(height: 6),
                    Text(context.str('storedetails_storeprofile_tapToUploadImage'), style: TextStyle(fontWeight: FontWeight.w600, color: tk.text2)),
                    Text(context.str('products_addproductscreen_jpgPngSupported'), style: TextStyle(fontSize: 12, color: tk.text3)),
                  ]),
                ),
              ),
              if (image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text('${context.str('storedetails_storeprofile_imageUploaded')} · ${context.str('storedetails_storeprofile_tapChangeToUpdate')}', style: TextStyle(fontSize: 12, color: tk.text3)),
                ),
              const SizedBox(height: 16),
              label('storedetails_storeprofile_timeSlabName'),
              TextField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clear(SlabField.name),
                decoration: InputDecoration(hintText: context.str('storedetails_storeprofile_timeSlabNamePlaceHolder'), errorText: err(SlabField.name)),
              ),
              const SizedBox(height: 14),
              label('storedetails_storeprofile_priority'),
              TextField(
                controller: _priority,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                onChanged: (_) => _clear(SlabField.priority),
                decoration: InputDecoration(hintText: context.str('products_products_sequence_placeholder'), errorText: err(SlabField.priority)),
              ),
              const SizedBox(height: 20),
              Text(context.str('storedetails_storeprofile_timeSettings'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 10),
              switchTile('storedetails_storeprofile_availableAllDay', 'storedetails_storeprofile_disableToSpecificHours', f.allDay, !f.custom, (v) => setState(() => _form = _collect().withAllDay(v))),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: timeBox(labelKey: 'storedetails_storeprofile_startTime', hintKey: 'storedetails_storeprofile_startTimeHint', value: f.start, field: SlabField.start, enabled: !timesLocked, onTap: () => _pickTime(start: true))),
                  const SizedBox(width: 12),
                  // "all day" fixes the end at 11:59 PM
                  Expanded(child: timeBox(labelKey: 'storedetails_storeprofile_endTime', hintKey: 'storedetails_storeprofile_endTimeHint', value: f.end, field: SlabField.end, enabled: !timesLocked && !f.allDay, onTap: () => _pickTime(start: false))),
                ],
              ),
              const SizedBox(height: 20),
              Text(context.str('storedetails_storeprofile_options'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 10),
              switchTile('storedetails_storeprofile_customPricing', 'storedetails_storeprofile_enableToSetACustomPrice', f.custom, true, (v) => setState(() => _form = _collect().withCustom(v))),
              if (f.custom) ...[
                const SizedBox(height: 12),
                label('storedetails_storeprofile_customPrice'),
                TextField(
                  controller: _price,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => _clear(SlabField.price),
                  decoration: InputDecoration(hintText: context.str('products_addproductscreen_variant_price_placeholder'), errorText: err(SlabField.price)),
                ),
              ],
              if (_serverError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_serverError!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('common_allscreen_cancel_button')))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: _busy
                        ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
                        : Text(context.str(_isNew ? 'storedetails_storeprofile_saveTimeSlab' : 'storedetails_storeprofile_updateTimeSlab')),
                  ),
                ),
              ]),
              if (!_isNew)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: tk.danger, minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(context.str('products_productdetail_delete_button')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}