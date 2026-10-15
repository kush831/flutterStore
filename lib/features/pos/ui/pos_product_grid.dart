import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter
import '../logic/pos_catalog_providers.dart';
import 'pos_product_card.dart';

/// The paged product grid of one category (empty id = All) and sub-category. Scrolling loads the next page.
/// The columns follow the width: as many 210 px cards as fit.
class PosProductGrid extends ConsumerWidget {
  const PosProductGrid({super.key, required this.productsKey, this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8)});

  final PosProductsKey productsKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(posProductsProvider(productsKey));
    final ctrl = ref.read(posProductsProvider(productsKey).notifier);
    final items = st.items;

    if (st.showShimmer) return const Center(child: CircularProgressIndicator());
    if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posanalysisscreen_retry_button', onAction: ctrl.refresh);
    if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.inventory_2_outlined, title: context.str('pos_posregisterscreen_no_products'));

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: ctrl.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 285),
                itemCount: items.length,
                itemBuilder: (_, i) => PosProductCard(product: items[i]),
              ),
            ),
            SliverToBoxAdapter(child: ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      ),
    );
  }
}