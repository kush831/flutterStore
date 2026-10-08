import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/catalog_models.dart';
import '../logic/catalog_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(categoryTreeProvider);
    try {
      await ref.read(categoryTreeProvider.future);
    } catch (_) {} // the error shows on screen
  }

  void _openSubs(MerchantCategory c) {
    final view = _SubCategoriesView(category: c, query: _query);
    if (MediaQuery.sizeOf(context).width >= 600) {
      showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640), child: view)));
    } else {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final async = ref.watch(categoryTreeProvider);
    final all = async.value;
    final shown = all == null ? const <MerchantCategory>[] : [for (final c in all) if (c.matches(_query)) c];

    final Widget list;
    if (all == null) {
      list = async.hasError
          ? SliverFillRemaining(
        hasScrollBody: false,
        child: _Message(icon: Icons.cloud_off_rounded, text: errorText(async.error!, ref.read(stringsProvider)), onRetry: _refresh),
      )
          : SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _TilesSkeleton()));
    } else if (all.isEmpty) {
      list = SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.category_outlined, text: context.str('pos_posallcategoriesscreen_empty')));
    } else if (shown.isEmpty) {
      list = SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.search_off_rounded, text: context.str('emptystate_emptystate_no_results_title')));
    } else {
      list = SliverPadding(
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 188),
          itemCount: shown.length,
          itemBuilder: (_, i) => _CategoryTile(c: shown[i], onTap: shown[i].subs.isEmpty ? null : () => _openSubs(shown[i])),
        ),
      );
    }

    return SubPage(
      title: context.str('products_categories_title'),
      fallbackRoute: Routes.more,
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 4, pad, 12),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.str('pos_posallcategoriesscreen_search_placeholder'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            list,
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.c, required this.onTap});

  final MerchantCategory c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final placeholder = ColoredBox(color: tk.sunken, child: Center(child: Icon(Icons.category_outlined, size: 30, color: tk.text3)));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 112,
              child: c.image.isEmpty
                  ? placeholder
                  : CachedNetworkImage(imageUrl: c.image, fit: BoxFit.cover, memCacheWidth: 500, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 36, child: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1, height: 1.3))),
                  const SizedBox(height: 6),
                  if (c.subs.isNotEmpty)
                    Container(
                      padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 4, bottom: 4),
                      decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${c.subs.length}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.primary)),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.primary),
                      ]),
                    )
                  else
                    const SizedBox(height: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sub-categories of one category (a sheet on phones, a dialog on wide screens).
class _SubCategoriesView extends StatelessWidget {
  const _SubCategoriesView({required this.category, required this.query});

  final MerchantCategory category;
  final String query; // sub-categories that match the search are bold

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final q = query.trim().toLowerCase();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                    Text('${category.subs.length}', style: TextStyle(color: tk.text2)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 8),
                  itemCount: category.subs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = category.subs[i];
                    final hit = q.isNotEmpty && s.name.toLowerCase().contains(q);
                    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.category_outlined, size: 20, color: tk.text3));
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: hit ? context.primary.withValues(alpha: 0.08) : tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: hit ? context.primary.withValues(alpha: 0.5) : tk.border)),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: s.image.isEmpty ? ph : CachedNetworkImage(imageUrl: s.image, fit: BoxFit.cover, memCacheWidth: 140, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.name, style: TextStyle(fontWeight: hit ? FontWeight.w800 : FontWeight.w600, color: hit ? context.primary : tk.text1))),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TilesSkeleton extends StatelessWidget {
  const _TilesSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: LayoutBuilder(builder: (_, box) {
      final cols = (box.maxWidth / 220).ceil().clamp(2, 6);
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < cols * 3; i++) SizedBox(width: w, height: 188, child: const SkeletonBox(radius: 16))]);
    }),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text1)),
          if (onRetry != null) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))],
        ]),
      ),
    );
  }
}