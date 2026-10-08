import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/products_repository.dart';
import '../data/variant_models.dart';
import '../logic/products_controller.dart';
import '../logic/variant_logic.dart';
import '../logic/variants_providers.dart';

class StockTab extends ConsumerWidget {
  const StockTab({super.key, required this.productId, required this.tracksInventory, required this.onOpenDetails});

  final String productId;

  /// Stock only exists when "Manage Inventory" is on for the product.
  final bool tracksInventory;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;

    if (!tracksInventory) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: tk.text3),
            const SizedBox(height: 12),
            Text(context.str('products_addproductscreen_inventory_title'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
            const SizedBox(height: 4),
            Text(context.str('products_addproductscreen_inventory_message'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onOpenDetails, child: Text(context.str('products_addproductscreen_productDetails'))),
          ]),
        ),
      );
    }

    final async = ref.watch(stockProvider(productId));
    final data = async.value;
    if (data == null) {
      if (async.hasError) {
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
              const SizedBox(height: 10),
              Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: () => ref.invalidate(stockProvider(productId)), child: Text(context.str('common_allscreen_try_again'))),
            ]),
          ),
        );
      }
      return const SkeletonPulse(child: Column(children: [SkeletonBox(height: 96, radius: 16), SizedBox(height: 10), SkeletonBox(height: 96, radius: 16)]));
    }

    if (data.variants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(Icons.layers_outlined, size: 52, color: tk.text3),
          const SizedBox(height: 12),
          Text(context.str('products_stockmanagement_noVariantsFound'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 640;
      final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final v in data.variants) SizedBox(width: w, child: _StockCard(v: v, onUpdate: () => _openEditor(context, v)))],
      );
    });
  }

  void _openEditor(BuildContext context, StockVariant v) {
    final editor = StockEditor(productId: productId, variant: v);
    if (MediaQuery.sizeOf(context).width >= 600) {
      showDialog<void>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700), child: editor)));
    } else {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => editor);
    }
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.v, required this.onUpdate});

  final StockVariant v;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final out = v.stock <= 0;
    final c = out ? tk.danger : tk.success;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('${v.stock}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                Text(context.str('products_stockmanagement_units'), style: TextStyle(fontSize: 10.5, color: c)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                  if (v.sku.isNotEmpty) Text('${context.str('products_stockmanagement_sku_label')} ${v.sku}', style: TextStyle(fontSize: 12, color: tk.text3)),
                ],
              ),
            ),
            FilledButton.tonal(onPressed: onUpdate, child: Text(context.str('products_stockmanagement_update_button'))),
          ],
        ),
      ),
    );
  }
}

/// Adjust the stock with − / +, and edit the cost and selling price. The server gets the NEW TOTAL.
class StockEditor extends ConsumerStatefulWidget {
  const StockEditor({super.key, required this.productId, required this.variant});

  final String productId;
  final StockVariant variant;

  @override
  ConsumerState<StockEditor> createState() => _StockEditorState();
}

class _StockEditorState extends ConsumerState<StockEditor> {
  int _change = 0;
  late final _cost = TextEditingController(text: widget.variant.cost);
  late final _selling = TextEditingController(text: widget.variant.selling);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cost.dispose();
    _selling.dispose();
    super.dispose();
  }

  bool get _pricesChanged => _cost.text.trim() != widget.variant.cost.trim() || _selling.text.trim() != widget.variant.selling.trim();

  /// Jetpack needs a change in the quantity; a change of the prices alone is allowed here too.
  bool get _canSave => !_saving && (_change != 0 || _pricesChanged);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final v = widget.variant;
      final message = await ref.read(productsRepositoryProvider).saveStock(
        variantId: v.id,
        newStock: stockAfter(v.stock, _change),
        cost: _cost.text,
        selling: _selling.text,
      );
      if (!mounted) return;
      ref.invalidate(stockProvider(widget.productId));
      ref.invalidate(variantsProvider(widget.productId));
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
    final v = widget.variant;
    final after = stockAfter(v.stock, _change);
    final changeColor = _change > 0 ? tk.success : (_change < 0 ? tk.danger : tk.text2);

    Widget stepButton(IconData icon, VoidCallback? onTap) => Material(
      color: onTap == null ? tk.sunken : context.primary.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 52, height: 52, child: Icon(icon, color: onTap == null ? tk.text3 : context.primary))),
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.str('products_stockmanagement_update_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                    Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2)),
                  ]),
                ),
                IconButton(onPressed: _saving ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.lg)),
                child: Column(
                  children: [
                    Text(context.str('products_stockmanagement_adjust_quantity_title'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        stepButton(Icons.remove_rounded, (_saving || !canDecrease(v.stock, _change)) ? null : () => setState(() => _change--)),
                        Text(_change > 0 ? '+$_change' : '$_change', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: changeColor)),
                        stepButton(Icons.add_rounded, _saving ? null : () => setState(() => _change++)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(context.str('products_stockmanagement_tapToChangeTheStockAmount'), style: TextStyle(fontSize: 12, color: tk.text3)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${context.str('products_stockmanagement_current')}: ${v.stock}', style: TextStyle(color: tk.text2)),
                        const SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: tk.text3),
                        const SizedBox(width: 12),
                        Text('${context.str('products_stockmanagement_afterUpdate')}: $after', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(context.str('products_stockmanagement_pricing'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text1)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str('products_stockmanagement_productCost'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2))),
                      TextField(controller: _cost, enabled: !_saving, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str('products_stockmanagement_sellingPrice'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2))),
                      TextField(controller: _selling, enabled: !_saving, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                    ]),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                child: _saving
                    ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
                    : Text(context.str('products_stockmanagement_update_button')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}