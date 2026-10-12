import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
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
            PosStaffStatusChip(status: m.status, serverText: m.statusLabel),
          ]),
        ),
      ),
    );
  }
}

// ── Staff ─────────────────────────────────────────────────────────────────────

class PosStaffScreen extends ConsumerWidget {
  const PosStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
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

    Widget label(String key, {Widget? trailing}) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))), ?trailing]));

    final Widget body;
    if (summary == null) {
      body = summaryAsync.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(summaryAsync.error!, ref.read(stringsProvider)), actionKey: 'pos_posstaffscreen_retry', onAction: refresh)
          : const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else {
      final members = list.items.take(5).toList();
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(children: [
            Expanded(child: PosStat(label: context.str('pos_posstaffscreen_active'), value: '${summary.active}', color: tk.success)),
            const SizedBox(width: 8),
            Expanded(child: PosStat(label: context.str('pos_posstaffscreen_on_break'), value: '${summary.onBreak}', color: tk.warning)),
            const SizedBox(width: 8),
            Expanded(child: PosStat(label: context.str('pos_posstaffscreen_offline'), value: '${summary.offline}', color: tk.text2)),
          ]),
          label('pos_posstaffscreen_team_members', trailing: TextButton(onPressed: () => context.push(Routes.posAllStaff), child: Text(context.str('pos_posstaffscreen_view_all')))),
          if (list.showShimmer)
            const ListSkeleton()
          else if (members.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(children: [Text(context.str('pos_posstaffscreen_no_staff_found'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)), Text(context.str('pos_posstaffscreen_no_staff_subtitle'), style: TextStyle(color: tk.text2))]))
          else
            for (final m in members) Padding(padding: const EdgeInsets.only(bottom: 8), child: PosStaffTile(m: m)),
          label('pos_posstaffscreen_roles_permissions', trailing: canManage ? TextButton(onPressed: () => context.push(Routes.posRoles), child: Text(context.str('pos_posstaffscreen_manage'))) : null),
          for (final r in summary.roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r.permCount}${context.str('pos_posstaffscreen_permissions_count_suffix')}'),
                  trailing: r.isSystem ? PosChip(context.str('pos_posstaffscreen_system'), tk.info) : null,
                ),
              ),
            ),
        ],
      );
    }

    return PosPage(
      title: context.str('pos_posstaffscreen_staff'),
      actions: [if (canManage) TextButton.icon(onPressed: add, icon: const Icon(Icons.person_add_alt_1_outlined, size: 20), label: Text(context.str('pos_posstaffscreen_add_staff')))],
      child: RefreshIndicator(onRefresh: refresh, child: body),
    );
  }
}

// ── All Staff ─────────────────────────────────────────────────────────────────

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
    final st = ref.watch(posStaffListProvider(_search));
    final ctrl = ref.read(posStaffListProvider(_search).notifier);
    final total = ref.watch(posStaffTotalProvider(_search));
    final items = st.items;

    final Widget list;
    if (st.showShimmer) {
      list = const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (st.showError) {
      list = FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('common_allscreen_something_went_wrong'), actionKey: 'pos_posanalysisscreen_retry_button', onAction: ctrl.refresh);
    } else if (items.isEmpty && st.loadedOnce && !st.hasMore) {
      list = FinanceMessage(icon: Icons.groups_2_outlined, title: context.str('pos_posstaffscreen_no_staff_found'), message: _search.isEmpty ? null : context.str('pos_posdashboardscreen_action_try_a_different_search'));
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 500) ctrl.loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i < items.length) return PosStaffTile(m: items[i]);
              if (!st.hasMore) return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(context.str('pos_posregisterscreen_all_members_loaded', [total ?? items.length]), style: TextStyle(fontSize: 12.5, color: tk.text3))));
              return ListFooter(hasMore: st.hasMore, loading: st.isLoadingMore, failed: st.loadMoreError != null, onRetry: ctrl.loadMore);
            },
          ),
        ),
      );
    }

    return PosPage(
      title: context.str('pos_posstaffscreen_all_staff'),
      back: Routes.posStaff,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _field,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _search = v.trim());
              });
            },
            decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_search_staff_placeholder'), prefixIcon: const Icon(Icons.search_rounded)),
          ),
        ),
        Expanded(child: list),
      ]),
    );
  }
}