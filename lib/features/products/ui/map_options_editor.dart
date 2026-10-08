import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/product_detail_models.dart';
import '../data/products_repository.dart';
import '../logic/option_logic.dart';
import '../logic/product_detail_providers.dart';
import '../logic/products_controller.dart';

Future<void> openMapOptions(BuildContext context, String productId) {
  final editor = MapOptionsEditor(productId: productId);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700), child: editor)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

class MapOptionsEditor extends ConsumerStatefulWidget {
  const MapOptionsEditor({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<MapOptionsEditor> createState() => _MapOptionsEditorState();
}

class _MapOptionsEditorState extends ConsumerState<MapOptionsEditor> {
  List<OptionGroup>? _groups; // the structure, from the server
  final Map<String, MappedOption> _state = {}; // id → ticked / amount
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(List<OptionGroup> groups) {
    _groups = groups;
    for (final g in groups) {
      for (final o in g.options) {
        _state[o.id] = o;
        _controllers[o.id] = TextEditingController(text: o.amount);
      }
    }
  }

  void _toggle(String id, bool on) {
    final o = _state[id]!;
    if (!on) _controllers[id]!.text = ''; // an unticked option has no amount (Jetpack)
    setState(() {
      _error = null;
      _state[id] = o.copyWith(checked: on, amount: on ? o.amount : '');
    });
  }

  List<MappedOption> _current() => [for (final o in _state.values) o.copyWith(amount: _controllers[o.id]!.text)];

  Future<void> _save() async {
    final all = _current();
    if (all.any((o) => !amountValid(o))) {
      setState(() => _error = context.str('products_addproductscreen_preparation_time_enterValidNumber'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await ref.read(productsRepositoryProvider).saveMappedOptions(widget.productId, all);
      if (!mounted) return;
      ref.invalidate(mappingOptionsProvider(widget.productId));
      ref.invalidate(productDetailProvider(widget.productId));
      ref.invalidate(productsProvider);
      Navigator.pop(context);
      showAppSnack(context, message.isEmpty ? context.str('common_allscreen_savedSuccessfully') : message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(mappingOptionsProvider(widget.productId));
    final data = async.value;
    if (data != null && _groups == null) _load(data);

    final Widget body;
    if (_groups == null) {
      body = async.hasError
          ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
          const SizedBox(height: 10),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(mappingOptionsProvider(widget.productId)), child: Text(context.str('common_allscreen_try_again'))),
        ]),
      )
          : const SkeletonPulse(child: Column(children: [SkeletonBox(height: 56, radius: 12), SizedBox(height: 8), SkeletonBox(height: 56, radius: 12), SizedBox(height: 8), SkeletonBox(height: 56, radius: 12)]));
    } else if (_groups!.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(Icons.tune_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 12),
          Text(context.str('products_addproductscreen_variant_noMappingOptionsFoundForThisProduct'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
          const SizedBox(height: 4),
          Text(context.str('products_addproductscreen_variant_pleaseAddOptionsFirst'), style: TextStyle(color: tk.text2)),
        ]),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in _groups!) ...[
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(g.type, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tk.text1))),
            for (final o in g.options) _OptionRow(option: _state[o.id]!, controller: _controllers[o.id]!, enabled: !_saving, onToggle: (v) => _toggle(o.id, v)),
          ],
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.tune_rounded, color: context.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.str('products_addproductscreen_variant_mapOptions'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                    Text(context.str('products_addproductscreen_variant_selectOptionsAndSetAmount'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
                  ]),
                ),
                IconButton(onPressed: _saving ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: body)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                ),
              ),
            if (_groups != null && _groups!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  child: _saving
                      ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
                      : Text(context.str('products_addproductscreen_variant_saveOptions')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.controller, required this.enabled, required this.onToggle});

  final MappedOption option;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final on = option.checked;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: on ? context.primary.withValues(alpha: 0.06) : tk.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: on ? context.primary.withValues(alpha: 0.4) : tk.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: enabled ? () => onToggle(!on) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
          child: Row(
            children: [
              Checkbox(value: on, onChanged: enabled ? (v) => onToggle(v ?? false) : null),
              Expanded(child: Text(option.name, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1))),
              if (on && option.showAmountField)
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(hintText: context.str('products_addproductscreen_variant_enterAmount'), isDense: true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}