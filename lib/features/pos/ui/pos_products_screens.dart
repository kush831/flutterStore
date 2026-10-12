import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../data/pos_catalog_models.dart';
import '../logic/pos_cart.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_catalog_providers.dart';
import 'pos_product_grid.dart';
import 'pos_view_cart_bar.dart';
import 'pos_widgets.dart';

/// The Products tab: food stores see the chip row and the grid, every other store sees the categories (Jetpack's rule).
class PosProductsEntry extends ConsumerWidget {
  const PosProductsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(posIsFoodProvider) ? const _FoodProducts() : const PosCategoriesScreen(tab: true);
}

// ── food: Register ────────────────────────────────────────────────────────────

class _FoodProducts extends ConsumerStatefulWidget {
  const _FoodProducts();

  @override
  ConsumerState<_FoodProducts> createState() => _FoodProductsState();
}

class _FoodProductsState extends ConsumerState<_FoodProducts> {
  String _categoryId = ''; // empty = All

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cats = ref.watch(posCategoriesProvider).value ?? const <PosCategory>[];
    final cart = ref.watch(posCartProvider);

    Widget chip(String label, String id, {int badge = 0}) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(badge > 0 ? '$label  $badge' : label),
        selected: _categoryId == id,
        onSelected: (_) => setState(() => _categoryId = id),
      ),
    );

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Expanded(child: Text(context.str('pos_posdashboardscreen_action_register'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1))),
              IconButton(onPressed: () => context.push(Routes.posSearch), icon: const Icon(Icons.search_rounded)),
            ]),
          ),
          SizedBox(
            height: 48,
            child: Row(children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [chip(context.str('pos_posregisterscreen_all'), ''), for (final c in cats) chip(c.name, c.id, badge: countForCategory(cart, c.id))],
                ),
              ),
              TextButton(onPressed: () => context.push(Routes.posCategories), child: Text(context.str('pos_posregisterscreen_see_all'))),
            ]),
          ),
          Expanded(child: PosProductGrid(key: ValueKey(_categoryId), productsKey: PosProductsKey(_categoryId))),
          const PosViewCartBar(),
        ],
      ),
    );
  }
}

// ── categories (grocery's Products tab, food's "See all") ─────────────────────

class PosCategoriesScreen extends ConsumerWidget {
  const PosCategoriesScreen({super.key, this.tab = false});

  final bool tab; // the Products tab itself (no back arrow), or a pushed page

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final async = ref.watch(posCategoriesProvider);
    final cats = async.value;
    final cart = ref.watch(posCartProvider);
    final isFood = ref.watch(posIsFoodProvider);
    final titleKey = (tab && !isFood) ? 'pos_posregisterscreen_categories_title' : 'pos_posallcategoriesscreen_title';

    final Widget body;
    if (cats == null) {
      body = async.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posanalysisscreen_retry_button', onAction: () async => ref.invalidate(posCategoriesProvider))
          : const Center(child: CircularProgressIndicator());
    } else if (cats.isEmpty) {
      body = FinanceMessage(icon: Icons.category_outlined, title: context.str('pos_posallcategoriesscreen_empty'));
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(posCategoriesProvider);
          try {
            await ref.read(posCategoriesProvider.future);
          } catch (_) {}
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 170),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final c = cats[i];
            final n = countForCategory(cart, c.id);
            final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.category_outlined, color: tk.text3, size: 30));
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(Uri(path: '${Routes.posCategory}/${Uri.encodeComponent(c.id)}', queryParameters: {'name': c.name, if (c.hasSubcategory) 'sub': '1'}).toString()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      c.image.isEmpty ? ph : CachedNetworkImage(imageUrl: c.image, fit: BoxFit.cover, memCacheWidth: 380, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph),
                      if (n > 0) PositionedDirectional(top: 8, end: 8, child: CircleAvatar(radius: 12, backgroundColor: context.primary, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)))),
                    ]),
                  ),
                  Padding(padding: const EdgeInsets.all(10), child: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
                ]),
              ),
            );
          },
        ),
      );
    }

    final content = Column(children: [Expanded(child: body), const PosViewCartBar()]);
    if (tab) {
      return SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 4), child: Row(children: [Expanded(child: Text(context.str(titleKey), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1))), IconButton(onPressed: () => context.push(Routes.posSearch), icon: const Icon(Icons.search_rounded))])),
          Expanded(child: content),
        ]),
      );
    }
    return PosPage(title: context.str(titleKey), back: Routes.posProducts, child: content);
  }
}

// ── one category's products (with sub-category chips when it has any) ─────────

class PosCategoryProductsScreen extends ConsumerStatefulWidget {
  const PosCategoryProductsScreen({super.key, required this.categoryId, required this.name, required this.hasSub});

  final String categoryId;
  final String name;
  final bool hasSub;

  @override
  ConsumerState<PosCategoryProductsScreen> createState() => _PosCategoryProductsScreenState();
}

class _PosCategoryProductsScreenState extends ConsumerState<PosCategoryProductsScreen> {
  String _subId = ''; // empty = the whole category

  @override
  Widget build(BuildContext context) {
    final subs = widget.hasSub ? (ref.watch(posSubcategoriesProvider(widget.categoryId)).value ?? const <PosCategory>[]) : const <PosCategory>[];

    Widget chip(String label, String id) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(label: Text(label), selected: _subId == id, onSelected: (_) => setState(() => _subId = id)),
    );

    return PosPage(
      title: widget.name,
      back: Routes.posProducts,
      child: Column(
        children: [
          if (subs.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [chip(context.str('pos_posregisterscreen_all'), ''), for (final s in subs) chip(s.name, s.id)]),
            ),
          Expanded(child: PosProductGrid(key: ValueKey('${widget.categoryId}/$_subId'), productsKey: PosProductsKey(widget.categoryId, _subId))),
          const PosViewCartBar(),
        ],
      ),
    );
  }
}