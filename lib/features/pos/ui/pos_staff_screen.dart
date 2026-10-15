import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListFooter, ListSkeleton
import '../data/pos_permission.dart';
import '../data/pos_staff_models.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_staff_logic.dart';
import '../logic/pos_staff_providers.dart';
import 'pos_staff_form_sheet.dart';
import 'pos_widgets.dart';

/// A team member as a row.
class PosStaffTile extends StatelessWidget {
  const PosStaffTile({super.key, required this.m});

  final PosStaffMember m;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('${Routes.posStaffMember}/${Uri.encodeComponent(m.staffId)}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            PosAvatar(initials: initialsOf(m.name, m.initials), colorHex: m.avatarColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                Text([m.roleName, m.shift].where((s) => s.isNotEmpty).join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
              ]),
            ),
            const SizedBox(width: 8),
            PosStaffStatusChip(status: m.status, serverText: m.statusLabel),
          ]),
        ),
      ),
    );
  }
}

// ── Staff ─────────────────────────────────────────────────────────────────────

/// Phone: one column, the "Add Staff" button in the app bar. Tablet and browser: the store app's page header with an
/// "Add staff" button, the three counters in a row, then the team on the left and the roles on the right.
class PosStaffScreen extends ConsumerWidget {
  const PosStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final summaryAsync = ref.watch(posStaffSummaryProvider);
    final summary = summaryAsync.value;
    final list = ref.watch(posStaffListProvider(''));
    final canManage = ref.watch(posAuthProvider.select((s) => s.can(PosPerm.staffManage)));

    Future<void> refresh() async {
      ref.invalidate(posStaffSummaryProvider);
      await ref.read(posStaffListProvider('').notifier).refresh();
    }

    Future<void> add() async {
      if (summary == null) return;
      if (await showStaffForm(context, roles: summary.roles) == true && context.mounted) showAppSnack(context, context.str('pos_posstaffscreen_staff_added_success'));
    }

    Widget label(String key, {Widget? trailing, double top = 18}) => Padding(padding: EdgeInsets.fromLTRB(4, top, 4, 8), child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))), ?trailing]));

    // ── before the summary is here ───────────────────────────────────────────
    if (summary == null) {
      final state = summaryAsync.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(summaryAsync.error!, ref.read(stringsProvider)), actionKey: 'pos_posstaffscreen_retry', onAction: refresh)
          : const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      return wide
          ? AdaptivePage(title: context.str('pos_posstaffscreen_staff'), subtitle: context.str('pos_posstaffscreen_subtitle'), child: state)
          : PosPage(title: context.str('pos_posstaffscreen_staff'), child: state);
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    final members = list.items.take(wide ? 8 : 5).toList();

    final counters = <Widget>[
      PosStat(label: context.str('pos_posstaffscreen_active'), value: '${summary.active}', color: tk.success),
      PosStat(label: context.str('pos_posstaffscreen_on_break'), value: '${summary.onBreak}', color: tk.warning),
      PosStat(label: context.str('pos_posstaffscreen_offline'), value: '${summary.offline}', color: tk.text2),
    ];

    final viewAll = TextButton(onPressed: () => context.push(Routes.posAllStaff), child: Text(context.str('pos_posstaffscreen_view_all')));
    final manage = canManage ? TextButton(onPressed: () => context.push(Routes.posRoles), child: Text(context.str('pos_posstaffscreen_manage'))) : null;

    final emptyTeam = Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [Text(context.str('pos_posstaffscreen_no_staff_found'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)), Text(context.str('pos_posstaffscreen_no_staff_subtitle'), style: TextStyle(color: tk.text2))]),
    );

    Widget roleCard(PosRoleSummary r) => Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${r.permCount}${context.str('pos_posstaffscreen_permissions_count_suffix')}'),
        trailing: r.isSystem ? PosChip(context.str('pos_posstaffscreen_system'), tk.info) : null,
      ),
    );

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(children: [for (var i = 0; i < counters.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: counters[i])]]),
          label('pos_posstaffscreen_team_members', trailing: viewAll),
          if (list.showShimmer)
            const ListSkeleton()
          else if (members.isEmpty)
            emptyTeam
          else
            for (final m in members) Padding(padding: const EdgeInsets.only(bottom: 8), child: PosStaffTile(m: m)),
          label('pos_posstaffscreen_roles_permissions', trailing: manage),
          for (final r in summary.roles) Padding(padding: const EdgeInsets.only(bottom: 8), child: roleCard(r)),
        ],
      );
      return PosPage(
        title: context.str('pos_posstaffscreen_staff'),
        actions: [if (canManage) TextButton.icon(onPressed: add, icon: const Icon(Icons.person_add_alt_1_outlined, size: 20), label: Text(context.str('pos_posstaffscreen_add_staff')))],
        child: RefreshIndicator(onRefresh: refresh, child: body),
      );
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    final body = LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 760;

      final team = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        label('pos_posstaffscreen_team_members', trailing: viewAll, top: 0),
        if (list.showShimmer)
          const ListSkeleton()
        else if (members.isEmpty)
          emptyTeam
        else
        // the members two to a row (one to a row when the column is narrow)
          LayoutBuilder(builder: (context, b) {
            final cols = b.maxWidth >= 520 ? 2 : 1;
            final rows = (members.length / cols).ceil();
            return Column(children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: 8),
                      Expanded(child: r * cols + c < members.length ? PosStaffTile(m: members[r * cols + c]) : const SizedBox.shrink()),
                    ],
                  ]),
                ),
            ]);
          }),
      ]);

      final roles = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        label('pos_posstaffscreen_roles_permissions', trailing: manage, top: 0),
        for (final r in summary.roles) Padding(padding: const EdgeInsets.only(bottom: 8), child: roleCard(r)),
      ]);

      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PosEqualRow(children: [for (var i = 0; i < counters.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: counters[i])]]),
            const SizedBox(height: 20),
            if (two)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: team), const SizedBox(width: 20), Expanded(flex: 5, child: roles)])
            else ...[team, const SizedBox(height: 16), roles],
          ],
        ),
      );
    });

    return AdaptivePage(
      title: context.str('pos_posstaffscreen_staff'),
      subtitle: context.str('pos_posstaffscreen_subtitle'),
      actions: [if (canManage) FilledButton.icon(onPressed: add, style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.person_add_alt_1_outlined, size: 20), label: Text(context.str('pos_posstaffscreen_add_staff')))],
      child: body,
    );
  }
}

// ── All Staff ─────────────────────────────────────────────────────────────────

/// Phone: cards in one column. Tablet: cards in two columns. Browser: a table.
class PosAllStaffScreen extends ConsumerStatefulWidget {
  const PosAllStaffScreen({super.key});

  @override
  ConsumerState<PosAllStaffScreen> createState() => _PosAllStaffScreenState();
}

class _PosAllStaffScreenState extends ConsumerState<PosAllStaffScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final st = ref.watch(posStaffListProvider(_search));
    final ctrl = ref.read(posStaffListProvider(_search).notifier);
    final total = ref.watch(posStaffTotalProvider(_search));
    final items = st.items;

    final searchField = TextField(
      controller: _field,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _search = v.trim());
        });
      },
      decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_search_staff_placeholder'), prefixIcon: const Icon(Icons.search_rounded)),
    );

    Widget? state() {
      if (st.showShimmer) return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      if (st.showError) return FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posanalysisscreen_retry_button', onAction: ctrl.refresh);
      if (items.isEmpty && st.loadedOnce && !st.hasMore) return FinanceMessage(icon: Icons.groups_2_outlined, title: context.str('pos_posstaffscreen_no_staff_found'), message: _search.isEmpty ? null : context.str('pos_posdashboardscreen_action_try_a_different_search'));
      return null;
    }

    Widget scrolling(Widget child) => NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(onRefresh: ctrl.refresh, child: child),
    );

    Widget endNote() => !st.hasMore
        ? Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(context.str('pos_posregisterscreen_all_members_loaded', [total ?? items.length]), style: TextStyle(fontSize: 12.5, color: tk.text3))))
        : ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);

    // ── cards: one column on a phone, two on a tablet ────────────────────────
    Widget cards(int cols, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)}) {
      final rows = (items.length / cols).ceil();
      return scrolling(
        ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: rows + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == rows) return endNote();
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(child: i * cols + c < items.length ? PosStaffTile(m: items[i * cols + c]) : const SizedBox.shrink()),
              ],
            ]);
          },
        ),
      );
    }

    // ── the table: browser and wide tablet ───────────────────────────────────
    Widget table() {
      Widget head(String key, {int flex = 1, TextAlign align = TextAlign.start}) => Expanded(flex: flex, child: Text(context.str(key), textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tk.text3)));
      Widget cell(String text, {int flex = 1, bool bold = false, Color? color}) => Expanded(flex: flex, child: Text(text.isEmpty ? '—' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? tk.text1)));

      Widget row(PosStaffMember m) => InkWell(
        onTap: () => context.push('${Routes.posStaffMember}/${Uri.encodeComponent(m.staffId)}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border))),
          child: Row(children: [
            Expanded(flex: 30, child: Row(children: [PosAvatar(initials: initialsOf(m.name, m.initials), colorHex: m.avatarColor, radius: 17), const SizedBox(width: 10), Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: tk.text1)))])),
            cell(m.roleName, flex: 18),
            cell(m.phone, flex: 18, color: tk.text2),
            cell(m.shift, flex: 20, color: tk.text2),
            Expanded(flex: 14, child: Align(alignment: AlignmentDirectional.centerEnd, child: PosStaffStatusChip(status: m.status, serverText: m.statusLabel))),
          ]),
        ),
      );

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
                  child: Row(children: [
                    head('pos_posstaffscreen_col_name', flex: 30),
                    head('pos_posstaffscreen_role', flex: 18),
                    head('pos_posstaffscreen_phone_number', flex: 18),
                    head('pos_posstaffscreen_shift_hours', flex: 20),
                    head('pos_posstaffscreen_col_status', flex: 14, align: TextAlign.end),
                  ]),
                ),
                for (final m in items) row(m),
              ]),
            ),
            endNote(),
          ],
        ),
      );
    }

    // ══ phone ═════════════════════════════════════════════════════════════════
    if (!wide) {
      return PosPage(
        title: context.str('pos_posstaffscreen_all_staff'),
        back: Routes.posStaff,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: searchField),
          Expanded(child: state() ?? cards(1)),
        ]),
      );
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    return AdaptivePage(
      title: context.str('pos_posstaffscreen_all_staff'),
      subtitle: total == null ? null : context.str('pos_posregisterscreen_all_members_loaded', [total]),
      fallbackRoute: Routes.posStaff,
      child: LayoutBuilder(builder: (context, box) {
        final asTable = box.maxWidth >= 860;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 360, child: searchField)),
          const SizedBox(height: 12),
          Expanded(child: state() ?? (asTable ? table() : cards(2, padding: const EdgeInsets.fromLTRB(0, 4, 0, 24)))),
        ]);
      }),
    );
  }
}