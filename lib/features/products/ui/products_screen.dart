import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/selected_scroll_row.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../logic/products_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.typeParam});

  /// ?type=OUTOFSTOCK | LOWSTOCK (Home's stock alerts and "Manage Stock")
  final String? typeParam;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  Timer? _debounce;

  late String _type = ProductQuery.normalizeType(widget.typeParam);
  ProductCategory? _category;
  String _searchText = '';
  late bool _hintHidden = ref.read(appPrefsProvider).productsHintDismissed;

  /// Jetpack's rule: the typed search wins, otherwise the category's name is the search text.
  ProductQuery get _query => ProductQuery(type: _type, searchText: _searchText.isNotEmpty ? _searchText : (_category?.name ?? ''));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductsScreen old) {
    super.didUpdateWidget(old);
    if (old.typeParam != widget.typeParam) setState(() => _type = ProductQuery.normalizeType(widget.typeParam));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() => ref.read(productsProvider(_query).notifier).refresh();

  void _onSearch(String v) {
    setState(() {}); // the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchText = v.trim();
        if (_searchText.isNotEmpty) _category = null; // typing replaces the category filter
      });
    });
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    setState(() => _searchText = '');
  }

  void _selectCategory(ProductCategory? c) {
    _search.clear();
    setState(() {
      _category = c;
      _searchText = '';
    });
  }

  void _dismissHint() {
    setState(() => _hintHidden = true);
    ref.read(appPrefsProvider).setProductsHintDismissed(true);
  }

  Future<void> _toggleProduct(Product p, bool on) async {
    final err = await ref.read(productsProvider(_query).notifier).toggleProduct(p.id, on);
    if (err != null && mounted) showAppSnack(context, err, error: true);
  }

  void _openVariants(Product p, String dashCurrency) {
    final view = VariantsView(query: _query, productId: p.id, fallbackCurrency: dashCurrency);
    if (MediaQuery.sizeOf(context).width >= 600) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640), child: view)),
      );
    } else {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final query = _query;
    final st = ref.watch(productsProvider(query));
    final ctrl = ref.read(productsProvider(query).notifier);
    final categories = ref.watch(productCategoriesProvider).value ?? const <ProductCategory>[];
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));
    final isFood = ref.watch(appPrefsProvider).isFood;
    final title = context.str('products_products_title');

    final catIndex = _category == null ? 0 : (categories.indexWhere((c) => c.id == _category!.id) + 1);

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.primary : tk.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: selected ? context.primary : tk.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : tk.text2)),
        ),
      ),
    );

    final items = st.items;
    final Widget listSliver;
    if (st.showShimmer) {
      listSliver = SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _GridSkeleton()));
    } else if (st.showError) {
      listSliver = SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.cloud_off_rounded, titleKey: 'common_allscreen_something_went_wrong', onRetry: ctrl.refresh));
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      final noStockSearch = _type == 'OUTOFSTOCK' && query.searchText.isEmpty;
      listSliver = SliverFillRemaining(
        hasScrollBody: false,
        child: _Message(
          icon: noStockSearch ? Icons.check_circle_outline_rounded : Icons.inventory_2_outlined,
          titleKey: noStockSearch ? 'products_products_noOutOfStockProducts' : 'emptystate_emptystate_no_products_title',
          messageKey: noStockSearch ? null : 'products_products_tryADifferentSearchOrClearTheFilters',
        ),
      );
    } else {
      listSliver = SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 272),
          itemCount: items.length,
          itemBuilder: (_, i) => _ProductTile(
            p: items[i],
            type: _type,
            isFood: isFood,
            currency: currency,
            onOpen: () => context.push(Routes.productDetail(items[i].id)),
            onVariants: () => _openVariants(items[i], currency),
            onToggle: (on) => _toggleProduct(items[i], on),
          ),
        ),
      );
    }

    final slivers = <Widget>[
      if (compact) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1)))),
      // ── the hint: where to tap to see the variants ──
      if (!_hintHidden) SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(pad, 8, pad, 4), child: _HintBanner(onClose: _dismissHint))),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.str('products_products_search_placeholder'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: _clearSearch, icon: const Icon(Icons.close_rounded, size: 20)),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
          child: _StockSegment(selected: _type, onChanged: (t) => setState(() => _type = t)),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 56,
          child: SelectedScrollRow(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
            selectedIndex: catIndex < 0 ? 0 : catIndex,
            children: [
              chip(context.str('products_products_all_category'), _category == null, () => _selectCategory(null)),
              for (final c in categories) chip(c.name, _category?.id == c.id, () => _selectCategory(c)),
            ],
          ),
        ),
      ),
      listSliver,
      SliverToBoxAdapter(child: _Footer(hasMore: st.hasMore && items.isNotEmpty, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
      const SliverToBoxAdapter(child: SizedBox(height: 96)), // room for the add button
    ];

    final scroll = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: ctrl.refresh,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
      ),
    );

    if (compact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        floatingActionButton: FloatingActionButton(
          tooltip: context.str('main_storedashboard_quick_action_add_product'),
          onPressed: () => context.push(Routes.productAdd),
          child: const Icon(Icons.add_rounded),
        ),
        body: SafeArea(bottom: false, child: scroll),
      );
    }

    return AdaptivePage(
      title: title,
      actions: [
        FilledButton.icon(
          onPressed: () => context.push(Routes.productAdd),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(context.str('main_storedashboard_quick_action_add_product')),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          onPressed: _refresh,
          icon: Icon(Icons.refresh_rounded, color: tk.text2),
        ),
      ],
      child: scroll,
    );
  }
}

// ── hint, filters ────────────────────────────────────────────────────────────

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: tk.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: tk.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 20, color: tk.info),
          const SizedBox(width: 10),
          Expanded(child: Text(context.str('products_products_variantsHint'), style: TextStyle(fontSize: 13, color: tk.text1, height: 1.4))),
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: tk.text2),
          ),
        ],
      ),
    );
  }
}

class _StockSegment extends StatelessWidget {
  const _StockSegment({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget seg(String value, String key) {
      final on = selected == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: on ? tk.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: on ? tk.border : Colors.transparent),
              ),
              child: Center(child: Text(context.str(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? tk.text1 : tk.text2))),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [
        seg('ALL', 'products_products_all_category'),
        seg('LOWSTOCK', 'products_products_low_stock'),
        seg('OUTOFSTOCK', 'products_products_out_of_stock_status'),
      ]),
    );
  }
}

// ── the tile ─────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.p,
    required this.type,
    required this.isFood,
    required this.currency,
    required this.onOpen,
    required this.onVariants,
    required this.onToggle,
  });

  final Product p;
  final String type;
  final bool isFood;
  final String currency;
  final VoidCallback onOpen;
  final VoidCallback onVariants;
  final ValueChanged<bool> onToggle;

  String get _price {
    final cur = p.currency.isNotEmpty ? p.currency : currency;
    final r = p.priceRange;
    if (r == null) return '';
    final lo = money(cur, r.min);
    return r.min == r.max ? lo : '$lo – ${money(cur, r.max)}';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final placeholder = ColoredBox(color: tk.sunken, child: Center(child: Icon(Icons.fastfood_outlined, size: 32, color: tk.text3)));

    Widget? chip;
    if (type == 'LOWSTOCK') {
      chip = _StockChip(text: context.str('products_products_low_stock_status'), color: tk.warning);
    } else if (p.tracksInventory) {
      chip = p.isOutOfStock
          ? _StockChip(text: context.str('products_products_out_of_stock_status'), color: tk.danger)
          : _StockChip(text: context.str('products_products_in_stock_status'), color: tk.success);
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: p.available ? 1 : 0.5,
                    child: p.picture.isEmpty
                        ? placeholder
                        : CachedNetworkImage(imageUrl: p.picture, fit: BoxFit.cover, memCacheWidth: 520, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
                  ),
                  if (isFood) PositionedDirectional(top: 8, start: 8, child: _VegMark(veg: p.isVeg)),
                  if (chip != null) PositionedDirectional(bottom: 8, start: 8, child: chip),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 36, child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tk.text1, height: 1.3))),
                  const SizedBox(height: 2),
                  Text(_price, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: p.variantCount == 0
                            ? const SizedBox.shrink()
                            : _VariantsButton(count: p.variantCount, onTap: onVariants),
                      ),
                      const SizedBox(width: 6),
                      _AvailSwitch(value: p.available, busy: p.busy, onChanged: onToggle),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 Variants ▾": opens the variants.
class _VariantsButton extends StatelessWidget {
  const _VariantsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.primary;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        child: Material(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 7, bottom: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text('$count ${context.str('products_productdetail_variants_title')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailSwitch extends StatelessWidget {
  const _AvailSwitch({required this.value, required this.busy, required this.onChanged});

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 30,
    child: busy
        ? Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.primary)))
        : FittedBox(child: Switch(value: value, onChanged: onChanged)),
  );
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(50)),
    child: Text(text, maxLines: 1, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
  );
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(2)),
          child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
        ),
      ),
    );
  }
}

// ── the variants (sheet on phones, dialog on wide screens) ───────────────────

/// Reads the product from the live list, so a switch moves as soon as it is tapped.
class VariantsView extends ConsumerStatefulWidget {
  const VariantsView({super.key, required this.query, required this.productId, required this.fallbackCurrency});

  final ProductQuery query;
  final String productId;
  final String fallbackCurrency;

  @override
  ConsumerState<VariantsView> createState() => _VariantsViewState();
}

class _VariantsViewState extends ConsumerState<VariantsView> {
  String? _error;

  Future<void> _toggle(Product p, ProductVariant v, bool on) async {
    setState(() => _error = null);
    final err = await ref.read(productsProvider(widget.query).notifier).toggleVariant(p.id, v.id, on);
    if (err != null && mounted) setState(() => _error = err); // shown here: a snackbar would hide behind the sheet
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final st = ref.watch(productsProvider(widget.query));
    final p = st.items.where((x) => x.id == widget.productId).firstOrNull;
    if (p == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));

    final currency = p.currency.isNotEmpty ? p.currency : widget.fallbackCurrency;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                        Text('${p.variantCount} ${context.str('products_productdetail_variants_title')}', style: TextStyle(color: tk.text2)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                  ),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 8),
                  itemCount: p.variants.length,
                  separatorBuilder: (_, _) => Divider(height: 20, color: tk.border),
                  itemBuilder: (_, i) => _VariantRow(p: p, v: p.variants[i], currency: currency, onToggle: (on) => _toggle(p, p.variants[i], on)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.p, required this.v, required this.currency, required this.onToggle});

  final Product p;
  final ProductVariant v;
  final String currency;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    // Jetpack's rule: when inventory is off and the quantity is 0, no stock info is shown
    final showStock = p.tracksInventory;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
              if (v.unit.isNotEmpty) Text(v.unit, style: TextStyle(fontSize: 12, color: tk.text3)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(money(currency, v.price), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                  if (v.hasDiscount) Text(v.discount, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tk.success)),
                  if (showStock)
                    v.outOfStock
                        ? _StockChip(text: context.str('products_products_out_of_stock_status'), color: tk.danger)
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                      _StockChip(text: context.str('products_products_in_stock_status'), color: tk.success),
                      const SizedBox(width: 6),
                      Text('${v.stock} ${context.str('products_products_qty')}', style: TextStyle(fontSize: 12, color: tk.text2)),
                    ]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _AvailSwitch(value: v.available, busy: v.busy, onChanged: onToggle),
      ],
    );
  }
}

// ── states ───────────────────────────────────────────────────────────────────

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: LayoutBuilder(
      builder: (_, box) {
        final cols = (box.maxWidth / 210).ceil().clamp(2, 6);
        final w = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < cols * 3; i++) SizedBox(width: w, height: 272, child: const SkeletonBox(radius: 16))]);
      },
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.hasMore, required this.loading, required this.failed, required this.onRetry});

  final bool hasMore;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) return Padding(padding: const EdgeInsets.all(12), child: Center(child: TextButton(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))));
    if (loading || hasMore) return const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    return const SizedBox.shrink();
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.titleKey, this.messageKey, this.onRetry});

  final IconData icon;
  final String titleKey;
  final String? messageKey;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: tk.text3),
            const SizedBox(height: 16),
            Text(context.str(titleKey), textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
            if (messageKey != null) ...[const SizedBox(height: 6), Text(context.str(messageKey!), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45))],
            if (onRetry != null) ...[const SizedBox(height: 18), FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))],
          ],
        ),
      ),
    );
  }
}