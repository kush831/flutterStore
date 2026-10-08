import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/choice_sheet.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/products_repository.dart';
import '../data/variant_models.dart';
import '../logic/products_controller.dart';
import '../logic/variant_logic.dart';
import '../logic/variants_providers.dart';
import 'map_options_editor.dart';

class VariantsTab extends ConsumerWidget {
  const VariantsTab({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final async = ref.watch(variantsProvider(productId));
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final data = async.value;

    if (data == null) {
      if (async.hasError) {
        return _ErrorBox(message: errorText(async.error!, ref.read(stringsProvider)), onRetry: () => ref.invalidate(variantsProvider(productId)));
      }
      return const SkeletonPulse(child: Column(children: [SkeletonBox(height: 92, radius: 16), SizedBox(height: 10), SkeletonBox(height: 92, radius: 16)]));
    }

    final count = data.variants.length;
    final countText = '$count ${context.str(count == 1 ? 'products_products_variant_singular' : 'products_products_variant_plural')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openMapOptions(context, productId),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                    Text(context.str('products_addproductscreen_variant_mapOptions'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                    Text(context.str('products_addproductscreen_variant_selectOptionsAndSetAmount'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: tk.text3),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text(countText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1))),
            FilledButton.icon(
              onPressed: () => openVariantEditor(context, productId: productId, data: data),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.str('products_productvariantslist_add_button')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.variants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(children: [
              Icon(Icons.layers_outlined, size: 52, color: tk.text3),
              const SizedBox(height: 12),
              Text(context.str('products_stockmanagement_noVariantsFound'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 4),
              Text(context.str('products_addproductscreen_variant_tapPlusToAddYourFirstVariant'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            ]),
          )
        else
          LayoutBuilder(builder: (context, box) {
            final two = box.maxWidth >= 640;
            final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final v in data.variants)
                  SizedBox(width: w, child: _VariantCard(v: v, data: data, currency: currency, onTap: () => openVariantEditor(context, productId: productId, data: data, variant: v))),
              ],
            );
          }),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.v, required this.data, required this.currency, required this.onTap});

  final Variant v;
  final VariantsData data;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final unit = data.unitName(v.weightUnitId);
    final weight = [v.weight, unit].where((e) => e.isNotEmpty).join(' ');
    final status = data.statusName(v.status);
    final available = v.status == '1';

    Widget chip(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.layers_rounded, color: context.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(money(currency, v.price), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                        if (v.hasDiscount) chip('-${v.discount}%', tk.success),
                        if (weight.isNotEmpty) Text(weight, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                        if (status.isNotEmpty) chip(status, available ? tk.success : tk.warning),
                      ],
                    ),
                    if (v.sku.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${context.str('products_stockmanagement_sku_label')} ${v.sku}', style: TextStyle(fontSize: 12, color: tk.text3))),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: tk.text3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── the editor (sheet on phones, dialog on wide screens) ─────────────────────

Future<void> openVariantEditor(BuildContext context, {required String productId, required VariantsData data, Variant? variant}) {
  final editor = VariantEditor(productId: productId, data: data, variant: variant);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720), child: editor)),
    );
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
}

class VariantEditor extends ConsumerStatefulWidget {
  const VariantEditor({super.key, required this.productId, required this.data, this.variant});

  final String productId;
  final VariantsData data;
  final Variant? variant; // null = a new variant

  @override
  ConsumerState<VariantEditor> createState() => _VariantEditorState();
}

class _VariantEditorState extends ConsumerState<VariantEditor> {
  bool get _isNew => widget.variant == null;

  late VariantForm _form = _isNew
      ? VariantForm(sku: widget.data.skuAutoGenerate ? widget.data.skuId : '', statusKey: widget.data.statuses.isNotEmpty ? widget.data.statuses.first.key : '1')
      : VariantForm.fromVariant(widget.variant!);

  late final _title = TextEditingController(text: _form.title);
  late final _sku = TextEditingController(text: _form.sku);
  late final _price = TextEditingController(text: _form.price);
  late final _discount = TextEditingController(text: _form.discount);
  late final _weight = TextEditingController(text: _form.weight);
  late final List<TextEditingController> _slabPrices = [for (final s in _form.slabs) TextEditingController(text: s.price)];

  Map<VariantField, String> _errors = {};
  String? _serverError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _sku, _price, _discount, _weight, ..._slabPrices]) {
      c.dispose();
    }
    super.dispose();
  }

  VariantForm _collect() => _form.copyWith(
    title: _title.text,
    sku: _sku.text,
    price: _price.text,
    discount: _discount.text,
    weight: _weight.text,
    slabs: [for (var i = 0; i < _form.slabs.length; i++) _form.slabs[i].copyWith(price: _slabPrices[i].text)],
  );

  void _clear(VariantField f) {
    if (_errors.containsKey(f)) setState(() => _errors = {..._errors}..remove(f));
  }

  Future<void> _pickUnit() async {
    final id = await showChoiceSheet(
      context,
      title: context.str('products_addproductscreen_variant_selectUnit'),
      items: [for (final u in widget.data.weightUnits) ChoiceItem(u.key, u.value)],
      selectedId: _form.weightUnitId.isEmpty ? null : _form.weightUnitId,
    );
    if (id == null || !mounted) return;
    setState(() => _form = _collect().copyWith(weightUnitId: id));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final f = _collect();
    final errors = validateVariant(f);
    setState(() {
      _form = f;
      _errors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final message = await ref.read(productsRepositoryProvider).saveVariant(widget.productId, widget.variant?.id ?? '', f);
      if (!mounted) return;
      // the lists that show this variant
      ref.invalidate(variantsProvider(widget.productId));
      ref.invalidate(stockProvider(widget.productId));
      ref.invalidate(productsProvider);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      showAppSnack(context, message.isEmpty ? context.str('common_allscreen_savedSuccessfully') : message);
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
    final d = widget.data;
    String? err(VariantField k) => _errors[k] == null ? null : context.str(_errors[k]!);

    Widget label(String key) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)));

    final unitName = d.unitName(_form.weightUnitId);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_isNew ? Icons.add_rounded : Icons.edit_rounded, color: context.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.str(_isNew ? 'products_addproductscreen_variant_add_title' : 'products_addproductscreen_variant_edit_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                        Text(_isNew ? context.str('products_addproductscreen_variant_fillInVariantDetails') : widget.variant!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text3)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: _saving ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              label('products_addproductscreen_variant_name_title'),
              TextField(
                controller: _title,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clear(VariantField.title),
                decoration: InputDecoration(hintText: context.str('products_addproductscreen_variant_name_placeholder'), errorText: err(VariantField.title)),
              ),
              const SizedBox(height: 14),
              label('products_addproductscreen_variant_sku_barcode_title'),
              TextField(
                controller: _sku,
                enabled: !_saving,
                readOnly: d.skuAutoGenerate,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: context.str('products_addproductscreen_variant_sku_barcode_placeholder'), suffixIcon: d.skuAutoGenerate ? Icon(Icons.auto_awesome_rounded, size: 18, color: tk.text3) : null),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('products_addproductscreen_variant_price_title'),
                      TextField(
                        controller: _price,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        onChanged: (_) => _clear(VariantField.price),
                        decoration: InputDecoration(errorText: err(VariantField.price)),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('products_addproductscreen_variant_discount_percentage_title'),
                      TextField(
                        controller: _discount,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        onChanged: (_) => _clear(VariantField.discount),
                        decoration: InputDecoration(suffixText: '%', errorText: err(VariantField.discount)),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('products_addproductscreen_variant_weight_title'),
                      TextField(
                        controller: _weight,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        onChanged: (_) => _clear(VariantField.weight),
                        decoration: InputDecoration(errorText: err(VariantField.weight)),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('products_addproductscreen_variant_selectUnit'),
                      InkWell(
                        borderRadius: BorderRadius.circular(Radii.md),
                        onTap: _saving ? null : _pickUnit,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
                          child: Row(children: [
                            Expanded(child: Text(unitName.isEmpty ? context.str('products_addproductscreen_variant_selectUnit') : unitName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unitName.isEmpty ? tk.text3 : tk.text1))),
                            Icon(Icons.keyboard_arrow_down_rounded, color: tk.text3),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Show Title
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.str('products_addproductscreen_variant_show_title'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                        Text(context.str(_form.titleShown ? 'products_addproductscreen_variant_shown' : 'products_addproductscreen_variant_hidden'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                      ]),
                    ),
                    Switch(value: _form.titleShown, onChanged: _saving ? null : (v) => setState(() => _form = _collect().copyWith(titleShown: v))),
                  ],
                ),
              ),
              if (d.statuses.isNotEmpty) ...[
                const SizedBox(height: 14),
                label('products_addproductscreen_variant_status_title'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in d.statuses)
                      InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _saving ? null : () => setState(() => _form = _collect().copyWith(statusKey: s.key)),
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: s.key == _form.statusKey ? context.primary : tk.surface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: s.key == _form.statusKey ? context.primary : tk.border),
                          ),
                          child: Text(s.value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.key == _form.statusKey ? Colors.white : tk.text2)),
                        ),
                      ),
                  ],
                ),
              ],
              if (_form.slabs.isNotEmpty) ...[
                const SizedBox(height: 18),
                Divider(color: tk.border),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 18, color: context.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.str('storedetails_storeprofile_productAvailableTimeSlabs'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
                ]),
                const SizedBox(height: 10),
                for (var i = 0; i < _form.slabs.length; i++) _SlabRow(slab: _form.slabs[i], controller: _slabPrices[i], enabled: !_saving, onToggle: (v) => setState(() => _form = _collect().copyWith(slabs: [for (var j = 0; j < _form.slabs.length; j++) j == i ? _form.slabs[j].copyWith(enabled: v) : _form.slabs[j]]))),
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
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('common_allscreen_cancel_button')))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: _saving
                          ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
                          : Text(context.str(_isNew ? 'products_productvariantslist_add_button' : 'common_allscreen_saveChanges')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlabRow extends StatelessWidget {
  const _SlabRow({required this.slab, required this.controller, required this.enabled, required this.onToggle});

  final SlabState slab;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: slab.enabled ? context.primary.withValues(alpha: 0.06) : tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: slab.enabled ? context.primary.withValues(alpha: 0.4) : tk.border)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(slab.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                  Text('${slab.start} – ${slab.end}', style: TextStyle(fontSize: 12.5, color: tk.text2)),
                ]),
              ),
              Switch(value: slab.enabled, onChanged: enabled ? onToggle : null),
            ],
          ),
          if (slab.enabled)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
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
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.cloud_off_rounded, size: 44, color: context.tk.text3),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.tk.text2)),
        const SizedBox(height: 14),
        FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
      ]),
    ),
  );
}