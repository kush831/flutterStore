import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
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
/// Phone: one column, a swipeable gallery, the button at the bottom. Tablet and browser: the store app's page header,
/// the gallery with thumbnails on the left, the figures and the button on the right, and the variants and options below.
class PosProductDetailScreen extends ConsumerWidget {
  const PosProductDetailScreen({super.key, required this.productId, this.product});

  final String productId;
  final PosProduct? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final async = ref.watch(posProductDetailProvider(productId));
    final d = async.value;
    final currency = ref.watch(posCurrencyProvider);
    final isFood = ref.watch(posIsFoodProvider);
    final cart = ref.watch(posCartProvider);
    String m(double v) => money(currency, posAmountText(v));
    final title = context.str('pos_posproductdetailscreen_title');

    // "Add to Cart" works from the list item it was opened from
    final p = product;
    final canAdd = p != null && !p.outOfStock;
    final room = p == null ? null : roomFor(cart, p, p.firstVariant);
    VoidCallback? addAction() {
      if (p == null) return null;
      if (!p.hasChoices && room == 0) return null;
      return () {
        if (p.hasChoices) {
          isFood ? showCustomizeSheet(context, p) : showVariantSheet(context, p);
        } else {
          ref.read(posCartProvider.notifier).add(p, p.firstVariant);
        }
      };
    }

    // ── before the product is here ───────────────────────────────────────────
    if (d == null) {
      final Widget state = async.hasError
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
      return wide
          ? AdaptivePage(title: title, fallbackRoute: Routes.posProducts, child: Center(child: state))
          : PosPage(title: title, back: Routes.posProducts, child: Column(children: [Expanded(child: state), const PosViewCartBar()]));
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    final range = priceRange(d.variants, d.options);

    Widget card(String? titleKey, List<Widget> children, {double top = 12}) => Padding(
      padding: EdgeInsets.only(top: top),
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

    final statusChip = PosChip(context.str(d.available ? 'pos_possessiondetailscreen_status_active' : 'pos_posterminalscreen_inactive'), d.available ? tk.success : tk.text3);

    final priceCard = range == null
        ? null
        : card('pos_posproductdetailscreen_price_range', [
      Text(range.min == range.max ? m(range.min) : '${m(range.min)} – ${m(range.max)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary)),
      Text(context.str('pos_posproductdetailscreen_price_range_subtitle'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
    ]);

    final descriptionCard = d.description.isEmpty ? null : card('pos_posproductdetailscreen_description_title', [Text(d.description, style: TextStyle(color: tk.text2, height: 1.45))]);
    final ingredientsCard = d.ingredients.isEmpty ? null : card('pos_productdetail_ingredients', [Text(d.ingredients, style: TextStyle(color: tk.text2, height: 1.45))]);

    final variantsCard = d.variants.isEmpty
        ? null
        : card('pos_posproductdetailscreen_variants_section_title', [
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
    ]);

    final optionsCard = card('pos_posproductdetailscreen_options', [
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
    ]);

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Swipe(images: d.gallery),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(d.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: tk.text1, height: 1.2))),
            const SizedBox(width: 8),
            statusChip,
          ]),
          if (d.sku.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(d.sku, style: TextStyle(color: tk.text3))),
          ?priceCard,
          ?descriptionCard,
          ?ingredientsCard,
          ?variantsCard,
          optionsCard,
        ],
      );
      final addBar = canAdd
          ? Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: FilledButton(onPressed: addAction(), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)), child: Text(context.str('pos_posproductdetailscreen_add_to_cart'))),
      )
          : null;
      return PosPage(title: title, back: Routes.posProducts, child: Column(children: [Expanded(child: body), ?addBar, const PosViewCartBar()]));
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    final addButton = canAdd ? FilledButton(onPressed: addAction(), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)), child: Text(context.str('pos_posproductdetailscreen_add_to_cart'))) : null;

    final body = LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 700;

      final gallery = _GalleryWithThumbs(images: d.gallery);
      final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (priceCard != null) card('pos_posproductdetailscreen_price_range', [
          Text(range!.min == range.max ? m(range.min) : '${m(range.min)} – ${m(range.max)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.primary)),
          Text(context.str('pos_posproductdetailscreen_price_range_subtitle'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
        ], top: 0),
        ?descriptionCard,
        ?ingredientsCard,
        if (addButton != null) ...[const SizedBox(height: 16), addButton],
      ]);

      final lower = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (variantsCard != null && two)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [card('pos_posproductdetailscreen_variants_section_title', _variantRows(context, d, m), top: 0)])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [card('pos_posproductdetailscreen_options', _optionRows(context, d, m), top: 0)])),
            ]),
          )
        else ...[?variantsCard, optionsCard],
      ]);

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: gallery), const SizedBox(width: 20), Expanded(flex: 6, child: info)]) else ...[gallery, const SizedBox(height: 16), info],
          lower,
        ]),
      );
    });

    return AdaptivePage(
      title: d.name,
      subtitle: d.sku.isEmpty ? null : d.sku,
      fallbackRoute: Routes.posProducts,
      actions: [statusChip],
      child: Column(children: [Expanded(child: body), const PosViewCartBar()]),
    );
  }

  List<Widget> _variantRows(BuildContext context, PosProductDetail d, String Function(double) m) {
    final tk = context.tk;
    return [
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
    ];
  }

  List<Widget> _optionRows(BuildContext context, PosProductDetail d, String Function(double) m) {
    final tk = context.tk;
    if (d.options.isEmpty) return [Text(context.str('pos_posproductdetailscreen_no_options'), style: TextStyle(color: tk.text3))];
    return [
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
    ];
  }
}

/// The phone's gallery: swipe through the photos.
class _Swipe extends StatefulWidget {
  const _Swipe({required this.images});

  final List<String> images;

  @override
  State<_Swipe> createState() => _SwipeState();
}

class _SwipeState extends State<_Swipe> {
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

/// The wide gallery: one big photo and a row of thumbnails under it.
class _GalleryWithThumbs extends StatefulWidget {
  const _GalleryWithThumbs({required this.images});

  final List<String> images;

  @override
  State<_GalleryWithThumbs> createState() => _GalleryWithThumbsState();
}

class _GalleryWithThumbsState extends State<_GalleryWithThumbs> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.image_outlined, size: 56, color: tk.text3));
    final images = widget.images;
    final at = _page.clamp(0, images.isEmpty ? 0 : images.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: images.isEmpty
              ? ph
              : Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(imageUrl: images[at], fit: BoxFit.cover, memCacheWidth: 1100, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph),
            if (at == 0)
              PositionedDirectional(
                top: 12,
                start: 12,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(50)), child: Text(context.str('pos_posproductdetailscreen_cover_tag'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
              ),
          ]),
        ),
      ),
      if (images.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () => setState(() => _page = i),
                child: Container(
                  width: 84,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: i == at ? context.primary : tk.border, width: i == at ? 2 : 1)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(Radii.md - 1), child: CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover, memCacheWidth: 260, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken))),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}