import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/pos_catalog_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_catalog_providers.dart';
import '../logic/pos_search_logic.dart';
import '../logic/pos_shift_logic.dart';
import 'pos_customize_sheet.dart';
import 'pos_variant_sheet.dart';
import 'pos_view_cart_bar.dart';
import 'pos_widgets.dart';

/// A product's full story: photos, description, variants and options. Jetpack's food and grocery product detail.
/// [product] is the list item it was opened from; it is what "Add to Cart" puts into the cart (null after a page reload).
class PosProductDetailScreen extends ConsumerWidget {
  const PosProductDetailScreen({super.key, required this.productId, this.product});

  final String productId;
  final PosProduct? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final async = ref.watch(posProductDetailProvider(productId));
    final d = async.value;
    final currency = ref.watch(posCurrencyProvider);
    final isFood = ref.watch(posIsFoodProvider);
    final cart = ref.watch(posCartProvider);
    String m(double v) => money(currency, posAmountText(v));

    final Widget body;
    if (d == null) {
      body = async.hasError
          ? Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 12),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(posProductDetailProvider(productId)), child: Text(context.str('pos_posanalysisscreen_retry_button'))),
        ]),
      )
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 240, radius: 16), SizedBox(height: 12), SkeletonBox(height: 80, radius: 16), SizedBox(height: 12), SkeletonBox(height: 140, radius: 16)])));
    } else {
      final range = priceRange(d.variants, d.options);
      Widget card(String? titleKey, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (titleKey != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
              ...children,
            ]),
          ),
        ),
      );

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Gallery(images: d.gallery),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(d.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: tk.text1, height: 1.2))),
            const SizedBox(width: 8),
            PosChip(context.str(d.available ? 'pos_possessiondetailscreen_status_active' : 'pos_posterminalscreen_inactive'), d.available ? tk.success : tk.text3),
          ]),
          if (d.sku.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(d.sku, style: TextStyle(color: tk.text3))),
          if (range != null)
            card('pos_posproductdetailscreen_price_range', [
              Text(range.min == range.max ? m(range.min) : '${m(range.min)} – ${m(range.max)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary)),
              Text(context.str('pos_posproductdetailscreen_price_range_subtitle'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
            ]),
          if (d.description.isNotEmpty) card('pos_posproductdetailscreen_description_title', [Text(d.description, style: TextStyle(color: tk.text2, height: 1.45))]),
          if (d.ingredients.isNotEmpty) card('pos_productdetail_ingredients', [Text(d.ingredients, style: TextStyle(color: tk.text2, height: 1.45))]),
          if (d.variants.isNotEmpty)
            card('pos_posproductdetailscreen_variants_section_title', [
              for (final v in d.variants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text([v.name, v.weightUnit].where((s) => s.isNotEmpty).join('  ·  '), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                        if (d.manageInventory && v.stock != null) Text(context.str('pos_posproductdetailscreen_stock', [v.stock!]), style: TextStyle(fontSize: 12, color: (v.stock! <= 0) ? tk.danger : tk.text3)),
                      ]),
                    ),
                    Text(m(posNum(v.price)), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                    const SizedBox(width: 8),
                    PosChip(context.str(v.available ? 'pos_possessiondetailscreen_status_active' : 'pos_posterminalscreen_inactive'), v.available ? tk.success : tk.text3),
                  ]),
                ),
            ]),
          card('pos_posproductdetailscreen_options', [
            if (d.options.isEmpty)
              Text(context.str('pos_posproductdetailscreen_no_options'), style: TextStyle(color: tk.text3))
            else
              for (final g in d.options) ...[
                if (g.type.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text(g.type, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
                for (final o in g.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(o.checked ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: o.checked ? tk.success : tk.border),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.name, style: TextStyle(color: tk.text2))),
                      if (posNum(o.amount) > 0) Text(m(posNum(o.amount)), style: TextStyle(color: tk.text2, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
          ]),
        ],
      );
    }

    // "Add to Cart" works from the list item it was opened from
    final p = product;
    Widget? addBar;
    if (p != null && !p.outOfStock) {
      final room = roomFor(cart, p, p.firstVariant);
      addBar = Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: FilledButton(
          onPressed: (!p.hasChoices && room == 0)
              ? null
              : () {
            if (p.hasChoices) {
              isFood ? showCustomizeSheet(context, p) : showVariantSheet(context, p);
            } else {
              ref.read(posCartProvider.notifier).add(p, p.firstVariant);
            }
          },
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          child: Text(context.str('pos_posproductdetailscreen_add_to_cart')),
        ),
      );
    }

    return PosPage(
      title: context.str('pos_posproductdetailscreen_title'),
      back: Routes.posProducts,
      child: Column(children: [Expanded(child: body), ?addBar, const PosViewCartBar()]),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.image_outlined, size: 48, color: tk.text3));
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: SizedBox(
        height: 260,
        child: widget.images.isEmpty
            ? ph
            : Stack(children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => CachedNetworkImage(imageUrl: widget.images[i], fit: BoxFit.cover, width: double.infinity, memCacheWidth: 900, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph),
          ),
          if (_page == 0)
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(50)), child: Text(context.str('pos_posproductdetailscreen_cover_tag'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < widget.images.length; i++) Container(width: i == _page ? 18 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: i == _page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)))]),
            ),
        ]),
      ),
    );
  }
}