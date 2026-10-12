import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/media/image_picking.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/packaging_models.dart';
import '../data/packaging_repository.dart';
import '../logic/packaging_logic.dart';

class PackagingResult {
  const PackagingResult({required this.deleted, required this.message});

  final bool deleted;
  final String message;
}

/// Add (pref == null) or edit. Returns what happened, or null when closed.
Future<PackagingResult?> showPackagingEditor(BuildContext context, {PackagingPref? pref}) {
  final editor = PackagingEditor(pref: pref);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<PackagingResult>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700), child: editor)));
  }
  return showModalBottomSheet<PackagingResult>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

Future<bool> confirmDeletePackaging(BuildContext context, String name) async {
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

class PackagingEditor extends ConsumerStatefulWidget {
  const PackagingEditor({super.key, this.pref});

  final PackagingPref? pref;

  @override
  ConsumerState<PackagingEditor> createState() => _PackagingEditorState();
}

class _PackagingEditorState extends ConsumerState<PackagingEditor> {
  bool get _isNew => widget.pref == null;

  late PackagingForm _form = _isNew ? const PackagingForm() : PackagingForm.fromPref(widget.pref!);
  late final _desc = TextEditingController(text: _form.description);
  late final _amount = TextEditingController(text: _form.amount);

  Map<PackagingField, String> _errors = {};
  String? _serverError;
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  PackagingForm _collect() => PackagingForm(description: _desc.text, amount: _amount.text, photo: _form.photo, iconUrl: _form.iconUrl);

  void _clear(PackagingField f) {
    if (_errors.containsKey(f)) setState(() => _errors = {..._errors}..remove(f));
  }

  Future<void> _pickIcon() async {
    final photo = await pickPhoto(context);
    if (photo != null && mounted) {
      final f = _collect();
      setState(() => _form = PackagingForm(description: f.description, amount: f.amount, photo: photo, iconUrl: f.iconUrl));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final f = _collect();
    final errors = validatePackaging(f);
    setState(() {
      _form = f;
      _errors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      final message = await ref.read(packagingRepositoryProvider).save(widget.pref?.id, f);
      if (!mounted) return;
      Navigator.pop(context, PackagingResult(deleted: false, message: message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = errorText(e, ref.read(stringsProvider)); // inside the editor: a snackbar would hide behind it
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirmDeletePackaging(context, widget.pref!.description) || !mounted) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      final message = await ref.read(packagingRepositoryProvider).delete(widget.pref!.id);
      if (!mounted) return;
      Navigator.pop(context, PackagingResult(deleted: true, message: message));
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
    String? err(PackagingField k) => _errors[k] == null ? null : context.str(_errors[k]!);
    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)));

    final image = f.photo != null
        ? Image.memory(f.photo!.bytes, fit: BoxFit.cover)
        : (f.iconUrl.isEmpty ? null : CachedNetworkImage(imageUrl: f.iconUrl, fit: BoxFit.cover, memCacheWidth: 300, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken)));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(_isNew ? Icons.add_rounded : Icons.edit_rounded, color: context.primary)),
                const SizedBox(width: 12),
                Expanded(child: Text(context.str('settings_settings_section_packagingPreferences'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 16),
              label('settings_settings_section_description'),
              TextField(
                controller: _desc,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clear(PackagingField.description),
                decoration: InputDecoration(hintText: context.str('settings_settings_section_descriptionPlaceHolder'), errorText: err(PackagingField.description)),
              ),
              const SizedBox(height: 14),
              label('settings_settings_section_amount'),
              TextField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => _clear(PackagingField.amount),
                decoration: InputDecoration(hintText: context.str('settings_settings_section_amountPlaceHolder'), errorText: err(PackagingField.amount)),
              ),
              const SizedBox(height: 14),
              label('settings_settings_section_imageOptional'),
              Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: _busy ? null : _pickIcon,
                  child: Container(
                    width: 84,
                    height: 84,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
                    child: image ?? Icon(Icons.add_photo_alternate_outlined, size: 30, color: tk.text3),
                  ),
                ),
                const SizedBox(width: 12),
                if (f.hasIcon) Expanded(child: Text(context.str('settings_settings_section_imageSelected'), style: TextStyle(color: tk.success, fontWeight: FontWeight.w600))),
              ]),
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : Text(context.str(_isNew ? 'common_allscreen_add' : 'common_allscreen_saveChanges')),
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