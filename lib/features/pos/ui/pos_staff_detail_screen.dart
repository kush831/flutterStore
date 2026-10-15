import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../data/pos_permission.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_repository.dart' show posBusinessIdProvider;
import '../data/pos_staff_models.dart';
import '../data/pos_staff_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_staff_logic.dart';
import '../logic/pos_staff_providers.dart';
import 'pos_staff_form_sheet.dart';
import 'pos_widgets.dart';

/// A staff member. Phone: one column, the buttons at the bottom. Tablet and browser: the store app's page header,
/// the buttons in a row under it, the permissions in cards on the left and the profile on the right.
class PosStaffDetailScreen extends ConsumerStatefulWidget {
  const PosStaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  @override
  ConsumerState<PosStaffDetailScreen> createState() => _PosStaffDetailScreenState();
}

class _PosStaffDetailScreenState extends ConsumerState<PosStaffDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() job, String successKey, {bool leave = false}) async {
    setState(() => _busy = true);
    try {
      await job();
      ref.invalidate(posStaffSummaryProvider);
      ref.invalidate(posStaffListProvider);
      ref.invalidate(posStaffDetailProvider(widget.staffId));
      if (!mounted) return;
      showAppSnack(context, context.str(successKey));
      if (leave) context.go(Routes.posStaff);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(PosStaffDetail d) async {
    final current = staffStatusOf(d.status);
    final picked = await showModalBottomSheet<StaffStatus>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(ctx.str('pos_posstaffscreen_change_status'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.tk.text1))),
          for (final s in [StaffStatus.active, StaffStatus.onBreak, StaffStatus.offline])
            ListTile(
              leading: Icon(s == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: s == current ? ctx.primary : ctx.tk.border),
              title: Text(ctx.str(statusTextKey(s))),
              onTap: () => Navigator.pop(ctx, s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    final value = picked == null ? null : statusUpdateValue(picked);
    if (value == null || picked == current || !mounted) return;
    final session = await ref.read(posActiveSessionProvider.future);
    await _run(() => ref.read(posStaffRepositoryProvider).changeStatus(ref.read(posBusinessIdProvider), staffId: d.staffId, status: value, sessionId: session?.id ?? ''), 'pos_posstaffscreen_status_updated_success');
  }

  Future<void> _changeRole(PosStaffDetail d) async {
    final roles = (await ref.read(posStaffSummaryProvider.future)).roles;
    if (!mounted) return;
    final picked = await showModalBottomSheet<PosRoleSummary>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(ctx.str('pos_posstaffscreen_change_role'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.tk.text1))),
          if (roles.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(ctx.str('pos_posstaffscreen_no_roles_found'))),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final r in roles)
                ListTile(
                  leading: Icon(r.id == d.roleId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: r.id == d.roleId ? ctx.primary : ctx.tk.border),
                  title: Text(r.name),
                  subtitle: Text('${r.permCount}${ctx.str('pos_posstaffscreen_permissions_count_suffix')}'),
                  trailing: r.isSystem ? PosChip(ctx.str('pos_posstaffscreen_system'), ctx.tk.info) : null,
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked == null || picked.id == d.roleId || !mounted) return;
    await _run(() => ref.read(posStaffRepositoryProvider).changeRole(ref.read(posBusinessIdProvider), staffId: d.staffId, roleId: picked.id), 'pos_posstaffscreen_role_changed_success');
  }

  Future<void> _deactivate(PosStaffDetail d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.person_off_outlined, size: 38, color: ctx.tk.danger),
        title: Text(ctx.str('pos_posstaffscreen_deactivate_staff_title')),
        content: Text('${ctx.str('pos_posstaffscreen_deactivate_message_prefix')}${d.name.isEmpty ? ctx.str('pos_posstaffscreen_this_staff_member') : d.name}${ctx.str('pos_posstaffscreen_deactivate_message_suffix')}', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posstaffscreen_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posstaffscreen_deactivate_button'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => ref.read(posStaffRepositoryProvider).deactivate(ref.read(posBusinessIdProvider), d.staffId), 'pos_posstaffscreen_staff_deactivated_success', leave: true);
  }

  Future<void> _edit(PosStaffDetail d) async {
    final roles = (await ref.read(posStaffSummaryProvider.future)).roles;
    if (!mounted) return;
    if (await showStaffForm(context, detail: d, roles: roles) == true && mounted) showAppSnack(context, context.str('pos_posstaffscreen_staff_updated_success'));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final async = ref.watch(posStaffDetailProvider(widget.staffId));
    final d = async.value;
    final auth = ref.watch(posAuthProvider);
    final canManage = auth.can(PosPerm.staffManage);
    final isMe = auth.staff?.staffId == widget.staffId; // you cannot deactivate yourself

    Future<void> refresh() async => ref.invalidate(posStaffDetailProvider(widget.staffId));

    // ── before the member is here ────────────────────────────────────────────
    if (d == null) {
      final Widget state = async.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'pos_posstaffscreen_retry', onAction: refresh)
          : const Padding(padding: EdgeInsets.all(16), child: SkeletonPulse(child: Column(children: [SkeletonBox(height: 140, radius: 16), SizedBox(height: 12), SkeletonBox(height: 220, radius: 16)])));
      return wide
          ? AdaptivePage(title: context.str('pos_posstaffscreen_staff'), fallbackRoute: Routes.posAllStaff, child: state)
          : PosPage(title: context.str('pos_posstaffscreen_staff'), back: Routes.posAllStaff, child: state);
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    Widget row(String key, String value) => value.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(color: tk.text2))), Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)))]));
    final groups = groupByModule(d.permissions);

    final profileCard = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          PosAvatar(initials: initialsOf(d.name, d.initials), colorHex: d.avatarColor, radius: 36),
          const SizedBox(height: 10),
          Text(d.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [PosChip(d.roleName, context.primary), PosStaffStatusChip(status: d.status, serverText: d.statusLabel), if (!d.isActive) PosChip(context.str('pos_posterminalscreen_inactive'), tk.danger)]),
        ]),
      ),
    );

    final infoCard = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
          row('pos_posstaffscreen_phone_number', d.phone),
          row('pos_posstaffscreen_role', d.roleName),
          row('pos_posstaffscreen_shift_hours', d.shiftStart.isEmpty ? d.shift : '${d.shiftStart} – ${d.shiftEnd}'),
        ]),
      ),
    );

    Widget permissionCard(MapEntry<String, List<PosStaffPermission>> g) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.key.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: context.primary)),
          const SizedBox(height: 6),
          for (final p in g.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(p.enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, size: 18, color: p.enabled ? tk.success : tk.border),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, color: p.enabled ? tk.text1 : tk.text3)), if (p.description.isNotEmpty) Text(p.description, style: TextStyle(fontSize: 12, color: tk.text3))])),
              ]),
            ),
        ]),
      ),
    );

    final permissionsLabel = '${context.str('pos_posstaffscreen_permissions')}${d.permLabel.isEmpty ? '' : '  ·  ${d.permLabel}'}';
    final historyPath = Uri(path: '${Routes.posStatusHistory}/${Uri.encodeComponent(d.staffId)}', queryParameters: {'name': d.name}).toString();
    final canDeactivate = canManage && !isMe && d.isActive;

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          profileCard,
          const SizedBox(height: 12),
          infoCard,
          const SizedBox(height: 18),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(permissionsLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
          for (final g in groups.entries) Padding(padding: const EdgeInsets.only(bottom: 10), child: permissionCard(g)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => context.push(historyPath), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), icon: const Icon(Icons.history_rounded), label: Text(context.str('pos_posstaffscreen_view_status_history'))),
          if (canManage) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _changeStatus(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_posstaffscreen_change_status')))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _changeRole(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_posstaffscreen_change_role')))),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _busy ? null : () => _edit(d), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), icon: const Icon(Icons.edit_outlined), label: Text(context.str('pos_posstaffscreen_edit_staff'))),
            if (canDeactivate) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: _busy ? null : () => _deactivate(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), foregroundColor: tk.danger, side: BorderSide(color: tk.danger)), icon: const Icon(Icons.person_off_outlined), label: Text(context.str('pos_posstaffscreen_deactivate_staff')))],
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 3)),
        ],
      );
      return PosPage(title: d.name.isNotEmpty ? d.name : context.str('pos_posstaffscreen_staff'), back: Routes.posAllStaff, child: RefreshIndicator(onRefresh: refresh, child: body));
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    final buttons = Wrap(spacing: 10, runSpacing: 10, children: [
      OutlinedButton.icon(onPressed: () => context.push(historyPath), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.history_rounded, size: 20), label: Text(context.str('pos_posstaffscreen_view_status_history'))),
      if (canManage) ...[
        OutlinedButton(onPressed: _busy ? null : () => _changeStatus(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(context.str('pos_posstaffscreen_change_status'))),
        OutlinedButton(onPressed: _busy ? null : () => _changeRole(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(context.str('pos_posstaffscreen_change_role'))),
        FilledButton.icon(onPressed: _busy ? null : () => _edit(d), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.edit_outlined, size: 20), label: Text(context.str('pos_posstaffscreen_edit_staff'))),
        if (canDeactivate) OutlinedButton.icon(onPressed: _busy ? null : () => _deactivate(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: tk.danger, side: BorderSide(color: tk.danger)), icon: const Icon(Icons.person_off_outlined, size: 20), label: Text(context.str('pos_posstaffscreen_deactivate_staff'))),
      ],
    ]);

    final body = LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 760;
      final entries = groups.entries.toList();

      // the permission cards in two columns (the first half on the left, the rest on the right)
      Widget permissions() {
        Widget col(List<MapEntry<String, List<PosStaffPermission>>> es) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < es.length; i++) ...[if (i > 0) const SizedBox(height: 12), permissionCard(es[i])]]);
        return LayoutBuilder(builder: (context, b) {
          if (b.maxWidth < 520 || entries.length < 2) return col(entries);
          final half = (entries.length + 1) ~/ 2;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: col(entries.sublist(0, half))), const SizedBox(width: 12), Expanded(child: col(entries.sublist(half)))]);
        });
      }

      final permsBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(permissionsLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))),
        permissions(),
      ]);
      final profileBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [profileCard, const SizedBox(height: 12), infoCard]);

      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 3)),
            buttons,
            const SizedBox(height: 20),
            if (two)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: permsBlock), const SizedBox(width: 20), Expanded(flex: 4, child: profileBlock)])
            else ...[profileBlock, const SizedBox(height: 16), permsBlock],
          ],
        ),
      );
    });

    return AdaptivePage(
      title: d.name.isNotEmpty ? d.name : context.str('pos_posstaffscreen_staff'),
      subtitle: [d.roleName, if (d.shiftStart.isNotEmpty) '${d.shiftStart} - ${d.shiftEnd}' else d.shift].where((s) => s.isNotEmpty).join(' · '),
      fallbackRoute: Routes.posAllStaff,
      actions: [PosStaffStatusChip(status: d.status, serverText: d.statusLabel)],
      child: body,
    );
  }
}

// ── Status history ────────────────────────────────────────────────────────────

/// Phone: cards. Tablet and browser: the store app's page header and a table (status, from, to, note).
class PosStatusHistoryScreen extends ConsumerWidget {
  const PosStatusHistoryScreen({super.key, required this.staffId, this.name = ''});

  final String staffId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final st = ref.watch(posStatusLogProvider(staffId));
    final ctrl = ref.read(posStatusLogProvider(staffId).notifier);
    final items = st.items;
    final back = '${Routes.posStaffMember}/${Uri.encodeComponent(staffId)}';

    Widget? state() {
      if (st.showShimmer) return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posstaffscreen_retry', onAction: ctrl.refresh);
      if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.history_rounded, title: context.str('pos_posstaffscreen_no_status_history_yet'));
      return null;
    }

    Widget scrolling(Widget child) => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(onRefresh: ctrl.refresh, child: child),
    );

    Widget endNote() => (!st.hasMore && items.isNotEmpty)
        ? Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(context.str('pos_posstaffscreen_all_records_loaded', [items.length]), style: TextStyle(fontSize: 12.5, color: tk.text3))))
        : ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);

    String when(String raw) => raw.isEmpty ? '—' : posDateTime(context, raw);

    // ── phone ────────────────────────────────────────────────────────────────
    Widget cards() => scrolling(
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == items.length) return endNote();
          final e = items[i];
          final range = [if (e.startedAt.isNotEmpty) posDateTime(context, e.startedAt), if (e.endedAt.isNotEmpty) posDateTime(context, e.endedAt)].join('  →  ');
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PosStaffStatusChip(status: e.status, serverText: e.status),
                if (range.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(range, style: TextStyle(fontSize: 12.5, color: tk.text2))),
                if (e.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.note, style: TextStyle(color: tk.text3))),
              ]),
            ),
          );
        },
      ),
    );

    // ── the table: tablet and browser ────────────────────────────────────────
    Widget table() {
      Widget head(String key, {int flex = 1}) => Expanded(flex: flex, child: Text(context.str(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3)));
      Widget cell(String text, {int flex = 1, Color? color}) => Expanded(flex: flex, child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: color ?? tk.text1)));
      return scrolling(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Container(
                  color: tk.sunken,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [head('pos_posstaffscreen_col_status', flex: 16), head('pos_posstaffscreen_col_from', flex: 24), head('pos_posstaffscreen_col_to', flex: 24), head('pos_posstaffscreen_col_note', flex: 36)]),
                ),
                for (final e in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(flex: 16, child: Align(alignment: AlignmentDirectional.centerStart, child: PosStaffStatusChip(status: e.status, serverText: e.status))),
                      cell(when(e.startedAt), flex: 24, color: tk.text2),
                      cell(when(e.endedAt), flex: 24, color: tk.text2),
                      cell(e.note.isEmpty ? '—' : e.note, flex: 36, color: tk.text2),
                    ]),
                  ),
              ]),
            ),
            endNote(),
          ],
        ),
      );
    }

    if (!wide) {
      return PosPage(title: name.isEmpty ? context.str('pos_posstaffscreen_status_history') : '${context.str('pos_posstaffscreen_status_history')} · $name', back: back, child: state() ?? cards());
    }
    return AdaptivePage(
      title: context.str('pos_posstaffscreen_status_history'),
      subtitle: name.isEmpty ? null : name,
      fallbackRoute: back,
      child: state() ?? table(),
    );
  }
}