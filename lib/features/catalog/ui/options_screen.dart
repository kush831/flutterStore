import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/catalog_models.dart';
import '../logic/catalog_providers.dart';
import 'option_editor.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  const OptionsScreen({super.key});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  Future<void> _add() async {
    final message = await showOptionEditor(context);
    if (message == null || !mounted) return;
    ref.invalidate(optionsProvider); // the new option shows in the list
    showAppSnack(context, context.str('settings_settings_row_optionAddedSuccessfully'));
  }

  Future<void> _edit(OptionItem o) async {
    final message = await showOptionEditor(context, item: o);
    if (message == null || !mounted) return;
    ref.invalidate(optionsProvider);
    showAppSnack(context, context.str('settings_settings_row_optionUpdatedSuccessfully'));
  }

  Future<void> _toggle(OptionItem o, bool on) async {
    final err = await ref.read(optionsProvider.notifier).setActive(o, on);
    if (!mounted) return;
    showAppSnack(context, err ?? context.str(on ? 'settings_settings_row_optionActivated' : 'settings_settings_row_optionDeActivated'), error: err != null);
  }

  Future<void> _delete(OptionItem o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 36, color: ctx.tk.danger),
        title: Text(ctx.str('settings_settings_row_deleteOption')),
        content: Text(o.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)),
            child: Text(ctx.str('products_productdetail_delete_button')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await ref.read(optionsProvider.notifier).remove(o);
    if (!mounted) return;
    showAppSnack(context, err ?? context.str('settings_settings_row_optionDeletedSuccessfully'), error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final st = ref.watch(optionsProvider);
    final ctrl = ref.read(optionsProvider.notifier);
    final items = st.items;

    return SubPage(
      title: context.str('settings_settings_row_options'),
      fallbackRoute: Routes.more,
      floatingActionButton: FloatingActionButton(tooltip: context.str('settings_settings_row_addNewOption'), onPressed: _add, child: const Icon(Icons.add_rounded)),
      actions: [
        if (!compact)
          FilledButton.icon(
            onPressed: _add,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(context.str('settings_settings_row_addNewOption')),
          ),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final table = box.maxWidth >= 760;

        final List<Widget> slivers;
        if (st.showShimmer) {
          slivers = [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _ListSkeleton()))];
        } else if (st.showError) {
          slivers = [SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.cloud_off_rounded, text: context.str('common_allscreen_something_went_wrong'), actionKey: 'common_allscreen_try_again', onAction: ctrl.refresh))];
        } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
          slivers = [SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.tune_rounded, text: context.str('settings_settings_row_noOptions'), actionKey: 'settings_settings_row_addNewOption', onAction: () async => _add()))];
        } else {
          slivers = [
            if (table) ...[
              const SliverToBoxAdapter(child: _TableHeader()),
              SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => _OptionRow(o: items[i], onToggle: (on) => _toggle(items[i], on), onEdit: () => _edit(items[i]), onDelete: () => _delete(items[i]))),
            ] else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _OptionCard(o: items[i], onToggle: (on) => _toggle(items[i], on), onEdit: () => _edit(items[i]), onDelete: () => _delete(items[i])),
                ),
              ),
            SliverToBoxAdapter(child: _Footer(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore)),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ];
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 500) ctrl.loadMore();
            return false;
          },
          child: RefreshIndicator(
            color: context.primary,
            onRefresh: ctrl.refresh,
            child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [SliverToBoxAdapter(child: SizedBox(height: compact ? 4 : 0)), ...slivers]),
          ),
        );
      }),
    );
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

class _StatusSwitch extends StatelessWidget {
  const _StatusSwitch({required this.o, required this.onToggle});

  final OptionItem o;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 30,
    child: o.busy ? Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.primary))) : FittedBox(child: Switch(value: o.active, onChanged: onToggle)),
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: context.tk.sunken, borderRadius: BorderRadius.circular(50)),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tk.text2)),
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.o, required this.onToggle, required this.onEdit, required this.onDelete});

  final OptionItem o;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                const SizedBox(height: 6),
                _TypeChip(o.type),
              ]),
            ),
            _StatusSwitch(o: o, onToggle: onToggle),
            IconButton(onPressed: o.busy ? null : onEdit, tooltip: context.str('settings_settings_row_EditOptions'), icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
            IconButton(onPressed: o.busy ? null : onDelete, tooltip: context.str('settings_settings_row_deleteOption'), icon: Icon(Icons.delete_outline_rounded, size: 20, color: tk.danger)),
          ],
        ),
      ),
    );
  }
}

const _cols = <int>[40, 30, 14, 16]; // flex of: name, type, status, actions

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.text2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tk.sunken,
        border: Border(top: BorderSide(color: tk.border), bottom: BorderSide(color: tk.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
      ),
      child: Row(children: [
        Expanded(flex: _cols[0], child: Text(context.str('settings_settings_row_optionName'), style: style)),
        Expanded(flex: _cols[1], child: Text(context.str('settings_settings_row_optionType'), style: style)),
        Expanded(flex: _cols[2], child: Text(context.str('settings_settings_row_status'), style: style)),
        Expanded(flex: _cols[3], child: Text(context.str('products_productdetail_actions_title'), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.o, required this.onToggle, required this.onEdit, required this.onDelete});

  final OptionItem o;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tk.border))),
        child: Row(children: [
          Expanded(flex: _cols[0], child: Text(o.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
          Expanded(flex: _cols[1], child: Align(alignment: AlignmentDirectional.centerStart, child: _TypeChip(o.type))),
          Expanded(flex: _cols[2], child: Align(alignment: AlignmentDirectional.centerStart, child: _StatusSwitch(o: o, onToggle: onToggle))),
          Expanded(
            flex: _cols[3],
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(onPressed: o.busy ? null : onEdit, tooltip: context.str('settings_settings_row_EditOptions'), icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
              IconButton(onPressed: o.busy ? null : onDelete, tooltip: context.str('settings_settings_row_deleteOption'), icon: Icon(Icons.delete_outline_rounded, size: 20, color: tk.danger)),
            ]),
          ),
        ]),
      ),
    );
  }
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

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(child: Column(children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 76, radius: 16))]));
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.actionKey, this.onAction});

  final IconData icon;
  final String text;
  final String? actionKey;
  final Future<void> Function()? onAction;

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
          if (onAction != null && actionKey != null) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: onAction, child: Text(context.str(actionKey!)))],
        ]),
      ),
    );
  }
}