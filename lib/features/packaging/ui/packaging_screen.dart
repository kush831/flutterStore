import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage: a generic icon + title + text + button
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/packaging_models.dart';
import '../data/packaging_repository.dart';
import 'packaging_editor.dart';

class PackagingScreen extends ConsumerStatefulWidget {
  const PackagingScreen({super.key});

  @override
  ConsumerState<PackagingScreen> createState() => _PackagingScreenState();
}

class _PackagingScreenState extends ConsumerState<PackagingScreen> {
  Future<void> _refresh() async {
    ref.invalidate(packagingProvider);
    try {
      await ref.read(packagingProvider.future);
    } catch (_) {} // the error shows on screen
  }

  void _done(PackagingResult? r) {
    if (r == null || !mounted) return;
    ref.invalidate(packagingProvider);
    final fallback = context.str(r.deleted ? 'common_allscreen_deleted_successfully' : 'common_allscreen_savedSuccessfully');
    showAppSnack(context, r.message.isEmpty ? fallback : r.message);
  }

  Future<void> _add() async => _done(await showPackagingEditor(context));

  Future<void> _edit(PackagingPref p) async => _done(await showPackagingEditor(context, pref: p));

  Future<void> _delete(PackagingPref p) async {
    if (!await confirmDeletePackaging(context, p.description) || !mounted) return;
    try {
      final message = await ref.read(packagingRepositoryProvider).delete(p.id);
      _done(PackagingResult(deleted: true, message: message));
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final async = ref.watch(packagingProvider);
    final items = async.value;
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));

    return SubPage(
      title: context.str('settings_settings_section_packagingPreferences'),
      fallbackRoute: Routes.more,
      floatingActionButton: FloatingActionButton(tooltip: context.str('common_allscreen_add'), onPressed: _add, child: const Icon(Icons.add_rounded)),
      actions: [
        if (!compact)
          FilledButton.icon(
            onPressed: _add,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(context.str('common_allscreen_add')),
          ),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final table = box.maxWidth >= 760;

        final Widget content;
        if (items == null) {
          content = async.hasError
              ? SliverFillRemaining(hasScrollBody: false, child: FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'common_allscreen_try_again', onAction: _refresh))
              : SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _TilesSkeleton()));
        } else if (items.isEmpty) {
          content = SliverFillRemaining(
            hasScrollBody: false,
            child: FinanceMessage(
              icon: Icons.inventory_2_outlined,
              title: context.str('settings_settings_section_noItem'),
              message: context.str('settings_settings_section_noItemSubtitle'),
              actionKey: 'common_allscreen_add',
              onAction: () async => _add(),
            ),
          );
        } else if (table) {
          content = SliverMainAxisGroup(slivers: [
            const SliverToBoxAdapter(child: _TableHeader()),
            SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => _PrefRow(p: items[i], currency: currency, onEdit: () => _edit(items[i]), onDelete: () => _delete(items[i]))),
          ]);
        } else {
          content = SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 160),
              itemCount: items.length,
              itemBuilder: (_, i) => _PrefTile(p: items[i], currency: currency, onTap: () => _edit(items[i])),
            ),
          );
        }

        return RefreshIndicator(
          color: context.primary,
          onRefresh: _refresh,
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [content]),
        );
      }),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.inventory_2_outlined, size: size * 0.4, color: tk.text3));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: size, height: size, child: url.isEmpty ? ph : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: (size * 3).round(), placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph)),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.p, required this.currency, required this.onTap});

  final PackagingPref p;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Center(child: Icon(Icons.inventory_2_outlined, size: 28, color: tk.text3)));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 84, child: p.icon.isEmpty ? ph : CachedNetworkImage(imageUrl: p.icon, fit: BoxFit.cover, memCacheWidth: 500, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1, height: 1.25)),
                const SizedBox(height: 3),
                Text(money(currency, p.amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.primary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

const _cols = <int>[10, 46, 22, 22]; // icon, description, amount, actions

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.text2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: tk.sunken, border: Border(top: BorderSide(color: tk.border), bottom: BorderSide(color: tk.border)), borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md))),
      child: Row(children: [
        Expanded(flex: _cols[0], child: const SizedBox.shrink()),
        Expanded(flex: _cols[1], child: Text(context.str('settings_settings_section_description'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(flex: _cols[2], child: Text(context.str('settings_settings_section_amount'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(flex: _cols[3], child: Text(context.str('products_productdetail_actions_title'), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.p, required this.currency, required this.onEdit, required this.onDelete});

  final PackagingPref p;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
          child: Row(children: [
            Expanded(flex: _cols[0], child: Align(alignment: AlignmentDirectional.centerStart, child: _Icon(url: p.icon, size: 38))),
            Expanded(flex: _cols[1], child: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
            Expanded(flex: _cols[2], child: Text(money(currency, p.amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
            Expanded(
              flex: _cols[3],
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(onPressed: onEdit, icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
                IconButton(onPressed: onDelete, tooltip: context.str('products_productdetail_delete_button'), icon: Icon(Icons.delete_outline_rounded, size: 20, color: tk.danger)),
              ]),
            ),
          ]),
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
      return Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < cols * 2; i++) SizedBox(width: w, height: 160, child: const SkeletonBox(radius: 16))]);
    }),
  );
}