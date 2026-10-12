import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_catalog_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_customize_logic.dart';
import '../logic/pos_shift_logic.dart';

Future<void> showCustomizeSheet(BuildContext context, PosProduct product, {PosCartItem? editing}) {
  final body = _CustomizeSheet(product: product, editing: editing);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760), child: body)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, isDismissible: false, builder: (_) => body);
}

/// Size → Extras → Review. The steps that do not apply to the product are left out.
class _CustomizeSheet extends ConsumerStatefulWidget {
  const _CustomizeSheet({required this.product,this.editing});

  final PosProduct product;
  final PosCartItem? editing;

  @override
  ConsumerState<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends ConsumerState<_CustomizeSheet> {
  late final List<CustomizeStep> _steps = stepsFor(widget.product);
  int _at = 0;
  late PosVariant _variant = widget.editing != null
      ? widget.product.variants.firstWhere((v) => v.id == widget.editing!.variant.id, orElse: () => widget.product.firstVariant)
      : widget.product.variants.firstWhere((v) => !(widget.product.manageInventory && v.stock != null && v.stock! <= 0), orElse: () => widget.product.firstVariant);
  late final Map<int, Set<String>> _chosen = {
    for (var i = 0; i < widget.product.modifiers.length; i++)
      i: widget.editing != null
          ? {for (final c in widget.product.modifiers[i].contents) if (widget.editing!.modifiers.any((m) => m.id == c.id)) c.id}
          : {for (final c in widget.product.modifiers[i].contents) if (c.selected) c.id},
  };
  late int _qty = widget.editing?.quantity ?? 1;

  CustomizeStep get _step => _steps[_at];

  List<PosModifierContent> get _mods => chosenModifiers(widget.product.modifiers, _chosen);

  bool get _canNext => switch (_step) {
    CustomizeStep.size => !(widget.product.manageInventory && _variant.stock != null && _variant.stock! <= 0),
    CustomizeStep.extras => extrasComplete(widget.product.modifiers, _chosen),
    CustomizeStep.review => true,
  };

  void _next() {
    if (_at < _steps.length - 1) {
      setState(() => _at++);
      return;
    }
    final cart = ref.read(posCartProvider.notifier);
    if (widget.editing != null) {
      cart.replace(widget.editing!.key, widget.product, _variant, modifiers: _mods, qty: _qty);
    } else {
      cart.add(widget.product, _variant, modifiers: _mods, qty: _qty);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = widget.product;
    final currency = ref.watch(posCurrencyProvider);
    final cart = ref.watch(posCartProvider);
    String m(double v) => money(currency, posAmountText(v));

    final unit = customizeUnit(_variant, _mods);
    final total = unit * _qty;
    final others = widget.editing == null ? cart : [for (final e in cart) if (e.key != widget.editing!.key) e];
    final room = roomFor(others, p, _variant);
    final canAdd = room == null || room >= _qty;
    final last = _at == _steps.length - 1;

    String stepLabel(CustomizeStep s) => context.str(switch (s) {
      CustomizeStep.size => 'pos_poswizardscreen_step_size',
      CustomizeStep.extras => 'pos_poswizardscreen_step_extras',
      CustomizeStep.review => 'pos_poswizardscreen_step_review',
    });

    Widget title(String titleKey, String subtitleKey) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.str(titleKey), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
        Text(context.str(subtitleKey), style: TextStyle(color: tk.text2)),
      ]),
    );

    Widget body() {
      switch (_step) {
        case CustomizeStep.size:
          return ListView(padding: const EdgeInsets.all(20), children: [
            title('pos_poswizardscreen_size_title', 'pos_poswizardscreen_size_subtitle'),
            for (final v in p.variants)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onTap: (p.manageInventory && v.stock != null && v.stock! <= 0) ? null : () => setState(() => _variant = v),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: v.id == _variant.id ? context.primary.withValues(alpha: 0.07) : tk.surface,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: v.id == _variant.id ? context.primary : tk.border, width: v.id == _variant.id ? 1.8 : 1),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.label, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                          if (v.hasDiscount) Text(context.str('pos_poswizardscreen_variant_discount', [m(v.base - v.unit), v.percentOff]), style: TextStyle(fontSize: 12, color: tk.success)),
                          if (p.manageInventory && v.stock != null && v.stock! <= 0) Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(fontSize: 12, color: tk.danger)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(m(v.unit), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                        if (v.hasDiscount) Text(m(v.base), style: TextStyle(fontSize: 12, color: tk.text3, decoration: TextDecoration.lineThrough)),
                      ]),
                      const SizedBox(width: 8),
                      Icon(v.id == _variant.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: v.id == _variant.id ? context.primary : tk.border),
                    ]),
                  ),
                ),
              ),
          ]);
        case CustomizeStep.extras:
          return ListView(padding: const EdgeInsets.all(20), children: [
            title('pos_poswizardscreen_extras_title', 'pos_poswizardscreen_extras_subtitle'),
            for (var gi = 0; gi < p.modifiers.length; gi++) ...[
              Row(children: [
                Expanded(child: Text(p.modifiers[gi].title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
                if (p.modifiers[gi].mandatory) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: tk.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(50)), child: Text(context.str('pos_posproductdetailscreen_required'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tk.danger))),
              ]),
              Text(context.str('pos_customize_choose_up_to', [p.modifiers[gi].limit]), style: TextStyle(fontSize: 12, color: tk.text3)),
              const SizedBox(height: 8),
              for (final c in p.modifiers[gi].contents)
                    () {
                  final on = (_chosen[gi] ?? const <String>{}).contains(c.id);
                  final atMax = !on && (_chosen[gi] ?? const <String>{}).length >= p.modifiers[gi].limit;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: atMax ? null : () => setState(() => _chosen[gi] = toggleModifier(p.modifiers[gi], _chosen[gi] ?? {}, c)),
                      child: Opacity(
                        opacity: atMax ? 0.45 : 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(color: on ? context.primary.withValues(alpha: 0.07) : tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: on ? context.primary : tk.border, width: on ? 1.6 : 1)),
                          child: Row(children: [
                            Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: on ? context.primary : tk.border),
                            const SizedBox(width: 10),
                            Expanded(child: Text(c.title, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1))),
                            Text(c.amount > 0 ? '+${m(c.amount)}' : context.str('pos_poswizardscreen_free'), style: TextStyle(color: tk.text2, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }(),
              const SizedBox(height: 12),
            ],
          ]);
        case CustomizeStep.review:
          final saved = customizeSavings(_variant, _qty);
          Widget row(String label, String value, {bool bold = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: bold ? tk.text1 : tk.text2, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: tk.text1))]),
          );
          return ListView(padding: const EdgeInsets.all(20), children: [
            title('pos_poswizardscreen_review_title', 'pos_poswizardscreen_review_subtitle'),
            Text(context.str('pos_poswizardscreen_list_section_title'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                  if (p.variants.length > 1) Text(_variant.label, style: TextStyle(color: tk.text2)),
                  for (final c in _mods) Text('+ ${c.title}', style: TextStyle(fontSize: 13, color: tk.text2)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.str('pos_poswizardscreen_review_section_price'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Column(children: [
                  row(context.str('pos_poswizardscreen_item_price'), m(_variant.unit)),
                  for (final c in _mods) row(c.title, c.amount > 0 ? m(c.amount) : context.str('pos_poswizardscreen_free')),
                  Divider(height: 14, color: tk.border),
                  row(context.str('pos_poswizardscreen_total'), m(total), bold: true),
                ]),
              ),
            ),
            if (saved > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tk.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [Icon(Icons.savings_outlined, size: 18, color: tk.success), const SizedBox(width: 8), Expanded(child: Text(context.str('pos_poswizardscreen_savings_banner_fmt', [m(saved)]), style: TextStyle(color: tk.success, fontWeight: FontWeight.w700)))]),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.str('pos_poswizardscreen_quantity'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), Text(context.str('pos_poswizardscreen_quantity_hint'), style: TextStyle(fontSize: 12, color: tk.text3))])),
              IconButton.filledTonal(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_rounded)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton.filled(onPressed: (room == null || _qty < room) ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add_rounded)),
            ]),
            if (!canAdd) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.str('pos_posproductlistscreen_out_of_stock'), style: TextStyle(color: tk.danger))),
          ]);
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.str('pos_poswizardscreen_customize'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)), Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1))])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          if (_steps.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) Expanded(child: Divider(color: i <= _at ? context.primary : tk.border, thickness: 2)),
                  Text(stepLabel(_steps[i]), style: TextStyle(fontSize: 12.5, fontWeight: i == _at ? FontWeight.w800 : FontWeight.w500, color: i <= _at ? context.primary : tk.text3)),
                ],
              ]),
            ),
          Flexible(child: body()),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.str('pos_poswizardscreen_running_total'), style: TextStyle(fontSize: 12, color: tk.text3)), Text(m(total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))])),
              if (_at > 0) TextButton(onPressed: () => setState(() => _at--), child: Text(MaterialLocalizations.of(context).backButtonTooltip)),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: (_canNext && (!last || canAdd)) ? _next : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                child: Text(last ? context.str('pos_poswizardscreen_add_to_cart', [m(total)]) : context.str('pos_poswizardscreen_next')),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}