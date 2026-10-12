import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_shift_models.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_widgets.dart';

/// Add (terminal == null) or edit. Returns true when it was saved.
Future<bool?> showTerminalEditor(BuildContext context, {PosTerminal? terminal}) {
  final editor = _TerminalEditor(terminal: terminal);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720), child: editor)));
  }
  return showModalBottomSheet<bool>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

class _TerminalEditor extends ConsumerStatefulWidget {
  const _TerminalEditor({this.terminal});

  final PosTerminal? terminal;

  @override
  ConsumerState<_TerminalEditor> createState() => _TerminalEditorState();
}

class _TerminalEditorState extends ConsumerState<_TerminalEditor> {
  bool get _isEdit => widget.terminal != null;

  late final _name = TextEditingController(text: widget.terminal?.name ?? '');
  late final _code = TextEditingController(text: widget.terminal?.code ?? '');
  late final _device = TextEditingController(text: widget.terminal?.deviceId ?? '');
  late final _note = TextEditingController(text: widget.terminal?.locationNote ?? '');
  late String _type = kTerminalTypes.contains(widget.terminal?.type) ? widget.terminal!.type : kTerminalTypes.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _device.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => terminalFormValid(name: _name.text, code: _code.text, deviceId: _device.text, isEdit: _isEdit);

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final bid = ref.read(posBusinessIdProvider);
    final repo = ref.read(posShiftRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateTerminal(bid, terminalId: widget.terminal!.id, name: _name.text, deviceId: _device.text, note: _note.text);
      } else {
        await repo.createTerminal(bid, name: _name.text, code: _code.text, type: _type, deviceId: _device.text, note: _note.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(context.str(_isEdit ? 'pos_posterminalscreen_edit_terminal' : 'pos_posterminalscreen_add_terminal'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              label('pos_posterminalscreen_terminal_name'),
              TextField(controller: _name, enabled: !_busy, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              if (!_isEdit) ...[
                label('pos_posterminalscreen_terminal_code'), // the code cannot be changed after the terminal exists
                TextField(controller: _code, enabled: !_busy, textInputAction: TextInputAction.next, onChanged: (_) => setState(() {})),
                const SizedBox(height: 14),
                label('pos_posterminalscreen_select_type'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in kTerminalTypes)
                    ChoiceChip(label: Text(context.str('pos_posterminalscreen_type_label', [titleCase(t)])), selected: _type == t, onSelected: _busy ? null : (_) => setState(() => _type = t)),
                ]),
                const SizedBox(height: 14),
              ],
              label('pos_posterminalscreen_device_id'),
              TextField(controller: _device, enabled: !_busy, textInputAction: TextInputAction.next, onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              label('pos_posterminalscreen_location_note'),
              TextField(controller: _note, enabled: !_busy, textCapitalization: TextCapitalization.sentences, maxLines: 2),
              if (_error != null) ...[const SizedBox(height: 14), PosErrorBox(_error!)],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_posterminalscreen_cancel')))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (_valid && !_busy) ? _save : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: Text(context.str(_busy ? (_isEdit ? 'pos_posterminalscreen_saving' : 'pos_posterminalscreen_adding') : (_isEdit ? 'pos_posterminalscreen_save_changes' : 'pos_posterminalscreen_add_terminal'))),
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