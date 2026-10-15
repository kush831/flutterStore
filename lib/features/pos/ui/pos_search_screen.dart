import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage
import '../data/pos_catalog_models.dart';
import '../logic/pos_catalog_providers.dart';
import '../logic/pos_search_logic.dart';
import 'pos_cart_screen.dart'; // PosWithCartPane
import 'pos_product_card.dart';
import 'pos_view_cart_bar.dart';
import 'pos_widgets.dart';

bool get _canScan => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Search products and categories, or scan a barcode. Jetpack's PosSearchScreen.
/// Phone: as it was. Tablet and browser: the store app's page header, the categories two to a row, and the live cart beside the results.
class PosSearchScreen extends ConsumerStatefulWidget {
  const PosSearchScreen({super.key});

  @override
  ConsumerState<PosSearchScreen> createState() => _PosSearchScreenState();
}

class _PosSearchScreenState extends ConsumerState<PosSearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _applied = ''; // the keyword that is searched

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _debounce?.cancel();
    setState(() {}); // the clear button
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _applied = v.trim());
    });
  }

  void _searchNow(String v) {
    _debounce?.cancel();
    setState(() => _applied = v.trim());
  }

  Future<void> _scan() async {
    final value = await context.push<String>(Routes.posScan);
    if (value == null || !mounted) return;
    final code = normalizeScan(value);
    _field.text = code;
    _field.selection = TextSelection.collapsed(offset: code.length);
    _searchNow(code); // the scanned code searches at once
  }

  void _openCategory(String id, String name, {bool hasSub = false}) => context.push(Uri(path: '${Routes.posCategory}/${Uri.encodeComponent(id)}', queryParameters: {'name': name, if (hasSub) 'sub': '1'}).toString());

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final ready = searchReady(_applied);
    final async = ready ? ref.watch(posSearchResultsProvider(_applied)) : null;
    final hPad = wide ? 0.0 : 12.0;

    Widget prompt() => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, size: 56, color: tk.text3),
          const SizedBox(height: 12),
          Text(context.str('pos_posgrocerysearchscreen_prompt_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 6),
          Text(context.str('pos_posgrocerysearchscreen_prompt'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          if (_canScan) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: _scan, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.qr_code_scanner_rounded, size: 20), const SizedBox(width: 8), Text(context.str('pos_posgrocerysearchscreen_scan_instead'))]))],
        ]),
      ),
    );

    Widget categoryCard(PosSearchCategory c) => Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        ListTile(
          onTap: () => _openCategory(c.id, c.name, hasSub: c.subs.isNotEmpty),
          leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: c.image.isEmpty ? ColoredBox(color: tk.sunken, child: Icon(Icons.category_outlined, color: tk.text3)) : CachedNetworkImage(imageUrl: c.image, fit: BoxFit.cover, memCacheWidth: 140, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken)))),
          title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
          trailing: Icon(Icons.chevron_right_rounded, color: tk.text3),
        ),
        if (c.subs.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: Align(alignment: AlignmentDirectional.centerStart, child: Wrap(spacing: 8, runSpacing: 6, children: [for (final s in c.subs) ActionChip(label: Text(s.name), onPressed: () => _openCategory(s.id, s.name))]))),
      ]),
    );

    Widget results(PosSearchResult r) {
      Widget label(String key) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

      // the categories: one to a row on a phone, two to a row when there is room
      Widget categories() => LayoutBuilder(builder: (context, box) {
        final cols = (wide && box.maxWidth >= 560) ? 2 : 1;
        final rows = (r.categories.length / cols).ceil();
        return Column(children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 8),
                  Expanded(child: i * cols + c < r.categories.length ? categoryCard(r.categories[i * cols + c]) : const SizedBox.shrink()),
                ],
              ]),
            ),
        ]);
      });

      return ListView(
        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 16),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(context.str('pos_possearchscreen_results_count', [r.count]), style: TextStyle(color: tk.text2))),
          if (r.categories.isNotEmpty) ...[label('pos_possearchscreen_categories'), categories()],
          if (r.products.isNotEmpty) ...[
            label('pos_possearchscreen_products'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 285),
              itemCount: r.products.length,
              itemBuilder: (_, i) => PosProductCard(product: r.products[i]),
            ),
          ],
        ],
      );
    }

    final Widget body;
    if (async == null) {
      body = prompt();
    } else {
      body = async.when(
        data: (r) => r.isEmpty
            ? FinanceMessage(icon: Icons.search_off_rounded, title: context.str('pos_posgrocerysearchscreen_no_results_title'), message: context.str('pos_posgrocerysearchscreen_no_results_subtitle').replaceAll(RegExp(r'\\+n'), '\n'))
            : results(r),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(e, ref.read(stringsProvider)), actionKey: 'pos_posanalysisscreen_retry_button', onAction: () async => ref.invalidate(posSearchResultsProvider(_applied))),
      );
    }

    final searchRow = Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _field,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _typed,
            onSubmitted: _searchNow,
            decoration: InputDecoration(
              hintText: context.str('pos_possearchscreen_placeholder'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _field.text.isEmpty ? null : IconButton(onPressed: () { _field.clear(); _searchNow(''); }, icon: const Icon(Icons.close_rounded)),
            ),
          ),
        ),
        if (_canScan) ...[const SizedBox(width: 8), IconButton.filledTonal(onPressed: _scan, tooltip: context.str('pos_possearchscreen_scan'), icon: const Icon(Icons.qr_code_scanner_rounded))],
      ]),
    );

    // the live cart sits beside the results when there is room and something in the cart
    return PosWithCartPane(
      child: PosPage(
        title: context.str('pos_possearchscreen_title'),
        subtitle: context.str('pos_possearchscreen_subtitle'),
        back: Routes.posProducts,
        child: Column(
          children: [
            searchRow,
            Expanded(child: body),
            const PosViewCartBar(),
          ],
        ),
      ),
    );
  }
}