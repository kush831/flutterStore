import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/choice_sheet.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../logic/catalog_providers.dart';

/// Add (item == null) or edit an option. Returns the server's message when it was saved, otherwise null.
Future<String?> showOptionEditor(BuildContext context, {OptionItem? item}) {
  final editor = OptionEditor(item: item);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640), child: editor)));
  }
  return showModalBottomSheet<String>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

class OptionEditor extends ConsumerStatefulWidget {
  const OptionEditor({super.key, this.item});

  final OptionItem? item;

  @override
  ConsumerState<OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends ConsumerState<OptionEditor> {
  bool get _isNew => widget.item == null;

  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late int _typeId = widget.item?.typeId ?? -1;
  late int _status = widget.item?.status ?? kOptionActive; // a new option starts active (Jetpack: the first choice)
  Map<OptionField, String> _errors = {};
  String? _serverError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickType(List<OptionType> types) async {
    final id = await showChoiceSheet(
      context,
      title: context.str('settings_settings_row_selectOptionType'),
      items: [for (final t in types) ChoiceItem('${t.id}', t.name)],
      selectedId: _typeId < 0 ? null : '$_typeId',
    );
    if (id == null || !mounted) return;
    setState(() {
      _typeId = int.tryParse(id) ?? -1;
      _errors = {..._errors}..remove(OptionField.type);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final errors = validateOption(name: _name.text, typeId: _typeId);
    setState(() {
      _errors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final message = await ref.read(catalogRepositoryProvider).saveOption(id: widget.item?.id, name: _name.text, typeId: _typeId, status: _status);
      if (!mounted) return;
      Navigator.pop(context, message.isEmpty ? '' : message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = errorText(e, ref.read(stringsProvider)); // inside the editor: a snackbar would hide behind it
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final types = ref.watch(optionTypesProvider);
    String typeName() {
      for (final t in types.value ?? const <OptionType>[]) {
        if (t.id == _typeId) return t.name;
      }
      return widget.item != null && widget.item!.typeId == _typeId ? widget.item!.type : ''; // the name from the list, until the types load
    }

    final nameErr = _errors[OptionField.name] == null ? null : context.str(_errors[OptionField.name]!);
    final typeErr = _errors[OptionField.type] == null ? null : context.str(_errors[OptionField.type]!);
    final name = typeName();

    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)));

    Widget statusChip(int value, String key) {
      final on = _status == value;
      return InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _saving ? null : () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: on ? context.primary : tk.surface, borderRadius: BorderRadius.circular(50), border: Border.all(color: on ? context.primary : tk.border)),
          child: Text(context.str(key), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : tk.text2)),
        ),
      );
    }

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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.str(_isNew ? 'settings_settings_row_addNewOption' : 'settings_settings_row_EditOptions'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                    if (!_isNew) Text(context.str('settings_settings_row_EditDetailsBelow'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                  ]),
                ),
                IconButton(onPressed: _saving ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 16),
              label('settings_settings_row_optionName'),
              TextField(
                controller: _name,
                enabled: !_saving,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_errors.containsKey(OptionField.name)) setState(() => _errors = {..._errors}..remove(OptionField.name));
                },
                decoration: InputDecoration(hintText: context.str('settings_settings_row_enterOptionName'), errorText: nameErr),
              ),
              const SizedBox(height: 14),
              label('settings_settings_row_optionType'),
              InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: (_saving || types.value == null) ? null : () => _pickType(types.value!),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: typeErr != null ? tk.danger : tk.border, width: typeErr != null ? 1.5 : 1)),
                  child: Row(children: [
                    Expanded(child: Text(name.isEmpty ? context.str('settings_settings_row_selectOptionType') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: name.isEmpty ? tk.text3 : tk.text1))),
                    if (types.isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.keyboard_arrow_down_rounded, color: tk.text3),
                  ]),
                ),
              ),
              if (typeErr != null || types.isLoading || types.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: types.hasError && typeErr == null
                      ? InkWell(onTap: () => ref.invalidate(optionTypesProvider), child: Text('${context.str('settings_settings_row_failedToLoadTypes')} · ${context.str('common_allscreen_try_again')}', style: TextStyle(fontSize: 12.5, color: tk.danger)))
                      : Text(typeErr ?? context.str('settings_settings_row_loadingTypes'), style: TextStyle(fontSize: 12.5, color: typeErr != null ? tk.danger : tk.text3)),
                ),
              const SizedBox(height: 14),
              label('settings_settings_row_status'),
              Wrap(spacing: 8, children: [statusChip(kOptionActive, 'products_stockmanagement_active'), statusChip(kOptionInactive, 'products_stockmanagement_inActive')]),
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
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('common_allscreen_cancel_button')))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: _saving
                        ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
                        : Text(context.str(_isNew ? 'settings_settings_row_addNewOption' : 'products_products_update_button')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}