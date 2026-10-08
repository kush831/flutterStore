import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/ui/home_format.dart';
import '../data/product_detail_models.dart';
import '../logic/product_detail_providers.dart';

const _kWide = 900.0;
const _kMaxWidth = 1100.0;

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  void _back() => context.canPop() ? context.pop() : context.go(Routes.products);

  Future<void> _refresh() async {
    ref.invalidate(productDetailProvider(widget.id));
    try {
      await ref.read(productDetailProvider(widget.id).future);
    } catch (_) {} // the error shows on screen
  }

  Future<void> _edit() async {
    await context.push(Routes.productEdit(widget.id));
    if (mounted) ref.invalidate(productDetailProvider(widget.id)); // what was edited shows at once
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(productDetailProvider(widget.id));
    final d = async.value;
    final wide = MediaQuery.sizeOf(context).width >= _kWide;
    final isFood = ref.watch(appPrefsProvider).isFood;

    Widget content;
    if (d != null) {
      content = wide ? _wide(d, isFood) : _phone(d, isFood);
    } else if (async.hasError) {
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Align(alignment: AlignmentDirectional.centerStart, child: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded))),
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 10),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: _refresh, child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      content = SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: const SkeletonPulse(child: Column(children: [SkeletonBox(height: 240, radius: 16), SizedBox(height: 12), SkeletonBox(height: 90, radius: 16), SizedBox(height: 12), SkeletonBox(height: 140, radius: 16)]))));
    }

    return Scaffold(
      backgroundColor: tk.canvas,
      bottomNavigationBar: (d != null && !wide)
          ? Container(
        decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton.icon(onPressed: _edit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), icon: const Icon(Icons.edit_rounded, size: 20), label: Text(context.str('products_productdetail_edit_button'))),
          ),
        ),
      )
          : null,
      body: RefreshIndicator(color: context.primary, onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [content])),
    );
  }

  // phone: gallery on top, then the cards
  Widget _phone(ProductDetail d, bool isFood) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Stack(children: [
        _Gallery(images: d.images, height: 280, available: d.available),
        PositionedDirectional(top: MediaQuery.paddingOf(context).top + 8, start: 8, child: _RoundButton(icon: Icons.arrow_back_rounded, onTap: _back)),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), child: _info(d, isFood)),
    ],
  );

  // wide: header, then the gallery next to the cards
  Widget _wide(ProductDetail d, bool isFood) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxWidth),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              IconButton(onPressed: _back, tooltip: MaterialLocalizations.of(context).backButtonTooltip, icon: const Icon(Icons.arrow_back_rounded)),
              const Spacer(),
              FilledButton.icon(onPressed: _edit, style: FilledButton.styleFrom(minimumSize: const Size(0, 46)), icon: const Icon(Icons.edit_rounded, size: 20), label: Text(context.str('products_productdetail_edit_button'))),
            ]),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: ClipRRect(borderRadius: BorderRadius.circular(Radii.lg), child: _Gallery(images: d.images, height: 400, available: d.available))),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: _info(d, isFood)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _info(ProductDetail d, bool isFood) {
    final tk = context.tk;
    final currency = d.currency;
    final range = d.priceRange;
    final price = range == null ? '' : (range.min == range.max ? money(currency, range.min) : '${money(currency, range.min)}');

    Widget card(String? titleKey, Widget child) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titleKey != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
            child,
          ],
        ),
      ),
    );

    final groups = d.mappedGroups;
    final cards = <Widget>[
      // name, availability, price
      card(
        null,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFood) Padding(padding: const EdgeInsets.only(top: 4, right: 8), child: _VegMark(veg: d.isVeg)),
                Expanded(child: Text(d.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: tk.text1, height: 1.2))),
                const SizedBox(width: 8),
                _StatusChip(active: d.available),
              ],
            ),
            if (range != null) ...[
              const SizedBox(height: 12),
              Text(context.str('products_productdetail_startingFrom'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
              Text(price, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.primary)),
              if (d.priceVaries) Text(context.str('products_productdetail_variesByVariantAndSelections'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
            ],
          ],
        ),
      ),
      if (d.description.isNotEmpty) card('products_products_description_title', SelectableText(d.description, style: TextStyle(color: tk.text1, height: 1.5))),
      if (isFood && d.ingredients.isNotEmpty) card('products_products_ingredients_title', SelectableText(d.ingredients, style: TextStyle(color: tk.text1, height: 1.5))),
      if (d.variants.isNotEmpty)
        card(
          'products_productdetail_variants_title',
          Column(children: [for (var i = 0; i < d.variants.length; i++) ...[if (i > 0) Divider(height: 20, color: tk.border), _VariantRow(v: d.variants[i], currency: currency, showStock: d.tracksInventory)]]),
        ),
      if (groups.isNotEmpty)
        card(
          'products_productdetail_options_title',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${groups.length} ${context.str('products_productdetail_option_groups_label')}', style: TextStyle(fontSize: 12.5, color: tk.text3)),
              for (final g in groups) ...[
                const SizedBox(height: 12),
                Text(g.type, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final o in g.options) _OptionChip(o: o, currency: currency)]),
              ],
            ],
          ),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 12), cards[i]]]);
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 22))),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.height, required this.available});

  final List<String> images;
  final double height;
  final bool available;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final placeholder = ColoredBox(color: tk.sunken, child: Center(child: Icon(Icons.fastfood_outlined, size: 52, color: tk.text3)));
    final images = widget.images;
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            placeholder
          else
            Opacity(
              opacity: widget.available ? 1 : 0.55,
              child: PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover, memCacheWidth: 1000, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: Motion.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: i == _page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = active ? tk.success : tk.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
      child: Text(context.str(active ? 'products_stockmanagement_active' : 'products_stockmanagement_inActive'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _VegMark extends StatelessWidget {
  const _VegMark({required this.veg});

  final bool veg;

  @override
  Widget build(BuildContext context) {
    final c = veg ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Semantics(
      label: context.str(veg ? 'products_productdetail_dietary_veg' : 'products_productdetail_dietary_non_veg'),
      child: Container(
        width: 20,
        height: 20,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(4)),
        child: Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.v, required this.currency, required this.showStock});

  final DetailVariant v;
  final String currency;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final out = v.stock.trim() == '0';
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: v.available ? tk.success : tk.text3, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text([v.name, v.unit].where((e) => e.isNotEmpty).join(' · '), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
              if (showStock && v.stock.isNotEmpty)
                Text('${context.str('products_productvariantslist_stock_value')} ${v.stock}', style: TextStyle(fontSize: 12.5, color: out ? tk.danger : tk.text2)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(currency, v.price), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
            if (v.hasDiscount) Text('-${v.discount}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.success)),
          ],
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.o, required this.currency});

  final MappedOption o;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasAmount = o.amount.trim().isNotEmpty && !RegExp(r'^[0\s.,]*$').hasMatch(o.amount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(50)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(o.name, style: TextStyle(fontSize: 13, color: tk.text1)),
        if (hasAmount) ...[const SizedBox(width: 6), Text('+${money(currency, o.amount)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tk.text2))],
      ]),
    );
  }
}