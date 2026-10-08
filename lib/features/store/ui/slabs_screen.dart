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
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/slab_models.dart';
import '../data/slabs_repository.dart';
import '../logic/store_logic.dart' show splitTime;
import 'slab_editor.dart';

class SlabsScreen extends ConsumerStatefulWidget {
  const SlabsScreen({super.key});

  @override
  ConsumerState<SlabsScreen> createState() => _SlabsScreenState();
}

class _SlabsScreenState extends ConsumerState<SlabsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(slabsProvider);
    try {
      await ref.read(slabsProvider.future);
    } catch (_) {} // the error shows on screen
  }

  void _done(SlabResult? r) {
    if (r == null || !mounted) return;
    ref.invalidate(slabsProvider);
    final fallback = context.str(r.deleted ? 'common_allscreen_deleted_successfully' : 'common_allscreen_savedSuccessfully');
    showAppSnack(context, r.message.isEmpty ? fallback : r.message);
  }

  Future<void> _add() async => _done(await showSlabEditor(context));

  Future<void> _edit(AvailabilitySlab s) async => _done(await showSlabEditor(context, slab: s));

  Future<void> _delete(AvailabilitySlab s) async {
    if (!await confirmDeleteSlab(context, s.name) || !mounted) return;
    try {
      final message = await ref.read(slabsRepositoryProvider).deleteSlab(s.id);
      _done(SlabResult(deleted: true, message: message));
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final pad = compact ? 16.0 : 0.0;
    final async = ref.watch(slabsProvider);
    final slabs = async.value;
    final currency = ref.watch(dashboardProvider.select((s) => s.home.value?.currency ?? ''));

    return SubPage(
      title: context.str('storedetails_storeprofile_screen_productAvailability'),
      fallbackRoute: Routes.storeProfile,
      floatingActionButton: FloatingActionButton(tooltip: context.str('storedetails_storeprofile_AddTimeSlab'), onPressed: _add, child: const Icon(Icons.add_rounded)),
      actions: [
        if (!compact)
          FilledButton.icon(
            onPressed: _add,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(context.str('storedetails_storeprofile_AddTimeSlab')),
          ),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final table = box.maxWidth >= 760;

        final Widget content;
        if (slabs == null) {
          content = async.hasError
              ? SliverFillRemaining(hasScrollBody: false, child: _Message(icon: Icons.cloud_off_rounded, title: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'common_allscreen_try_again', onAction: _refresh))
              : SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const _TilesSkeleton()));
        } else if (slabs.isEmpty) {
          content = SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(
              icon: Icons.schedule_rounded,
              title: context.str('storedetails_storeprofile_noTimeSlabsYet'),
              message: context.str('storedetails_storeprofile_createYourFirstProductAvailability').replaceAll(RegExp(r'\\+n'), '\n'),
              actionKey: 'storedetails_storeprofile_addFirstSlab',
              onAction: () async => _add(),
            ),
          );
        } else if (table) {
          content = SliverMainAxisGroup(slivers: [
            const SliverToBoxAdapter(child: _TableHeader()),
            SliverList.builder(itemCount: slabs.length, itemBuilder: (_, i) => _SlabRow(s: slabs[i], currency: currency, onEdit: () => _edit(slabs[i]), onDelete: () => _delete(slabs[i]))),
          ]);
        } else {
          content = SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 176),
              itemCount: slabs.length,
              itemBuilder: (_, i) => _SlabTile(s: slabs[i], currency: currency, onTap: () => _edit(slabs[i])),
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

// ── shared bits ──────────────────────────────────────────────────────────────

String _range(BuildContext context, AvailabilitySlab s) {
  final loc = MaterialLocalizations.of(context);
  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
  String show(String hhmm) {
    final t = splitTime(hhmm);
    return loc.formatTimeOfDay(TimeOfDay(hour: t.hour, minute: t.minute), alwaysUse24HourFormat: h24);
  }

  return '${show(s.start)} – ${show(s.end)}';
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
  );
}

/// All Day, Custom + price, or the time range.
class _When extends StatelessWidget {
  const _When({required this.s, required this.currency});

  final AvailabilitySlab s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (s.custom) {
      return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _Chip(context.str('storedetails_storeprofile_custom'), tk.warning),
        if (s.customPrice.isNotEmpty) Text(money(currency, s.customPrice), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tk.text1)),
      ]);
    }
    if (s.allDay) return Align(alignment: AlignmentDirectional.centerStart, child: _Chip(context.str('storedetails_storeprofile_allDay'), tk.info));
    if (s.hasRange) return Text(_range(context, s), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2));
    return const SizedBox.shrink();
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.priority);

  final String priority;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 24),
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Text(priority.isEmpty ? '–' : priority, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.primary)),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size, this.radius = 10});

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Icon(Icons.schedule_rounded, size: size * 0.4, color: tk.text3));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: url.isEmpty ? ph : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: (size * 3).round(), placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph)),
    );
  }
}

// ── tile (phone) ─────────────────────────────────────────────────────────────

class _SlabTile extends StatelessWidget {
  const _SlabTile({required this.s, required this.currency, required this.onTap});

  final AvailabilitySlab s;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ph = ColoredBox(color: tk.sunken, child: Center(child: Icon(Icons.schedule_rounded, size: 28, color: tk.text3)));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 92, child: s.image.isEmpty ? ph : CachedNetworkImage(imageUrl: s.image, fit: BoxFit.cover, memCacheWidth: 500, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))), const SizedBox(width: 6), _PriorityBadge(s.priority)]),
                  const SizedBox(height: 6),
                  _When(s: s, currency: currency),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── table (wide) ─────────────────────────────────────────────────────────────

const _cols = <int>[8, 10, 26, 24, 18, 14]; // flex of: image, priority, name, time, pricing, actions

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
        Expanded(flex: _cols[1], child: Text(context.str('storedetails_storeprofile_priority'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(flex: _cols[2], child: Text(context.str('storedetails_storeprofile_timeSlabName'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(flex: _cols[3], child: Icon(Icons.schedule_rounded, size: 16, color: tk.text2)),
        Expanded(flex: _cols[4], child: Text(context.str('storedetails_storeprofile_customPricing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Expanded(flex: _cols[5], child: Text(context.str('products_productdetail_actions_title'), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }
}

class _SlabRow extends StatelessWidget {
  const _SlabRow({required this.s, required this.currency, required this.onEdit, required this.onDelete});

  final AvailabilitySlab s;
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
            Expanded(flex: _cols[0], child: Align(alignment: AlignmentDirectional.centerStart, child: _Thumb(url: s.image, size: 38))),
            Expanded(flex: _cols[1], child: Align(alignment: AlignmentDirectional.centerStart, child: _PriorityBadge(s.priority))),
            Expanded(flex: _cols[2], child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))),
            Expanded(
              flex: _cols[3],
              child: s.allDay
                  ? Align(alignment: AlignmentDirectional.centerStart, child: _Chip(context.str('storedetails_storeprofile_allDay'), tk.info))
                  : Text(s.hasRange ? _range(context, s) : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2)),
            ),
            Expanded(
              flex: _cols[4],
              child: s.custom
                  ? Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [_Chip(context.str('storedetails_storeprofile_custom'), tk.warning), if (s.customPrice.isNotEmpty) Text(money(currency, s.customPrice), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))])
                  : Text('—', style: TextStyle(color: tk.text3)),
            ),
            Expanded(
              flex: _cols[5],
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(onPressed: onEdit, tooltip: context.str('storedetails_storeprofile_editTimeSlab'), icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
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
      return Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < cols * 2; i++) SizedBox(width: w, height: 176, child: const SkeletonBox(radius: 16))]);
    }),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.message, this.actionKey, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionKey;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: tk.text3),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45))],
          if (onAction != null && actionKey != null) ...[const SizedBox(height: 18), FilledButton.tonal(onPressed: onAction, child: Text(context.str(actionKey!)))],
        ]),
      ),
    );
  }
}