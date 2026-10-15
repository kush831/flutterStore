import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListSkeleton
import '../data/pos_roles_models.dart';
import '../data/pos_roles_repository.dart';
import '../data/pos_shift_repository.dart' show posBusinessIdProvider;
import '../logic/pos_auth.dart';
import '../logic/pos_roles_logic.dart';
import '../logic/pos_staff_providers.dart';
import 'pos_widgets.dart';

final posRolesProvider = FutureProvider.autoDispose<List<PosRole>>((ref) {
  ref.watch(posScopeProvider);
  return ref.watch(posRolesRepositoryProvider).roles(ref.watch(posBusinessIdProvider));
});

void _roleChanged(WidgetRef ref) {
  ref.invalidate(posRolesProvider);
  ref.invalidate(posStaffSummaryProvider); // the Staff screen lists the roles too
  ref.invalidate(posStaffListProvider);
}

/// The roles of the store, with the way to create, edit and delete them. Jetpack's POSManageRolesScreen.
/// Phone: cards in one column. Tablet and browser: the store app's page header, and the roles in a grid of cards.
class PosRolesScreen extends ConsumerWidget {
  const PosRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final async = ref.watch(posRolesProvider);
    final roles = async.value;

    Future<void> create() async {
      if (await showRoleEditor(context) == true && context.mounted) showAppSnack(context, context.str('pos_posrolesscreen_roleCreatedSuccessfully'));
    }

    Future<void> edit(PosRole r) async {
      if (await showRoleEditor(context, role: r) == true && context.mounted) showAppSnack(context, context.str('pos_posrolesscreen_roleUpdatedSuccessfully'));
    }

    Future<void> delete(PosRole r) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, size: 38, color: ctx.tk.danger),
          title: Text(ctx.str('pos_posrolesscreen_delete_role_confirmation', [r.name])),
          content: Text(ctx.str('pos_posrolesscreen_deleteRoleWarning'), textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posstaffscreen_cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posrolesscreen_delete_role'))),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      try {
        await ref.read(posRolesRepositoryProvider).delete(ref.read(posBusinessIdProvider), r.id);
        _roleChanged(ref);
        if (context.mounted) showAppSnack(context, context.str('pos_posrolesscreen_roleDeletedSuccessfully'));
      } catch (e) {
        if (context.mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
      }
    }

    Future<void> refresh() async {
      ref.invalidate(posRolesProvider);
      try {
        await ref.read(posRolesProvider.future);
      } catch (_) {}
    }

    // the same card on every width
    Widget roleCard(PosRole r) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Flexible(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))), if (r.isSystem) ...[const SizedBox(width: 8), PosChip(context.str('pos_posstaffscreen_system'), tk.info)]]),
              if (r.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.text2))),
              const SizedBox(height: 4),
              Text('${r.permissionCount} ${context.str('pos_posrolesscreen_perms')}${r.createdAt.isEmpty ? '' : '  ·  ${posDateTime(context, r.createdAt)}'}', style: TextStyle(fontSize: 12.5, color: tk.text3)),
            ]),
          ),
          IconButton(onPressed: () => edit(r), tooltip: context.str('pos_posrolesscreen_edit_role'), icon: const Icon(Icons.edit_outlined)),
          if (canDeleteRole(r)) IconButton(onPressed: () => delete(r), tooltip: context.str('pos_posrolesscreen_delete_role'), icon: Icon(Icons.delete_outline_rounded, color: tk.danger)),
        ]),
      ),
    );

    // ── before the roles are here ────────────────────────────────────────────
    Widget? state() {
      if (roles == null) {
        return async.hasError
            ? FinanceMessage(icon: Icons.cloud_off_rounded, title: errorText(async.error!, ref.read(stringsProvider)), actionKey: 'pos_posstaffscreen_retry', onAction: () async => ref.invalidate(posRolesProvider))
            : const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
      }
      if (roles.isEmpty) return FinanceMessage(icon: Icons.admin_panel_settings_outlined, title: context.str('pos_posrolesscreen_noRoleCreatedAt'), message: context.str('pos_posrolesscreen_tapToCreateYourFirstRole'));
      return null;
    }

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final Widget body = state() ??
          RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: roles!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => roleCard(roles[i]),
            ),
          );
      return PosPage(
        title: context.str('pos_posstaffscreen_roles_permissions'),
        back: Routes.posStaff,
        actions: [IconButton(onPressed: create, tooltip: context.str('pos_posrolesscreen_create_role'), icon: const Icon(Icons.person_add_alt_1_outlined))],
        child: body,
      );
    }

    // ══ tablet and browser: the roles in a grid of cards ══════════════════════
    final Widget body = state() ??
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 980 ? 3 : (box.maxWidth >= 620 ? 2 : 1);
          final rows = (roles!.length / cols).ceil();
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: rows,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => PosEqualRow(children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(child: i * cols + c < roles.length ? roleCard(roles[i * cols + c]) : const SizedBox.shrink()),
                ],
              ]),
            ),
          );
        });

    return AdaptivePage(
      title: context.str('pos_posstaffscreen_roles_permissions'),
      subtitle: context.str('pos_posrolesscreen_subtitle'),
      fallbackRoute: Routes.posStaff,
      actions: [FilledButton.icon(onPressed: create, style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.add_rounded, size: 20), label: Text(context.str('pos_posrolesscreen_create_role')))],
      child: body,
    );
  }
}

// ── the role editor (create and edit) ─────────────────────────────────────────

/// Create a role (role == null) or edit one. Returns true when it was saved.
/// Phone: a bottom sheet. Tablet and browser: a wider dialog with the permission groups in two columns.
Future<bool?> showRoleEditor(BuildContext context, {PosRole? role}) {
  final body = _RoleEditor(role: role);
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 600) {
    return showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width >= 900 ? 760 : 560, maxHeight: 800), child: body)));
  }
  return showModalBottomSheet<bool>(context: context, isScrollControlled: true, isDismissible: false, useSafeArea: true, builder: (_) => body);
}

/// What the editor lists: for a new role every permission; for an existing role its own record (with what it already has).
final _editorDataProvider = FutureProvider.autoDispose.family<PosRoleDetail, String>((ref, roleId) async {
  final repo = ref.watch(posRolesRepositoryProvider);
  if (roleId.isEmpty) return PosRoleDetail(role: const PosRole(id: ''), all: await repo.allPermissions());
  return repo.role(ref.watch(posBusinessIdProvider), roleId);
});

class _RoleEditor extends ConsumerStatefulWidget {
  const _RoleEditor({this.role});

  final PosRole? role;

  @override
  ConsumerState<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends ConsumerState<_RoleEditor> {
  bool get _isEdit => widget.role != null;

  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _desc = TextEditingController(text: widget.role?.description ?? '');
  Set<String>? _chosen; // set once the role's own permissions have loaded
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save(Set<String> chosen) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final bid = ref.read(posBusinessIdProvider);
    final repo = ref.read(posRolesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(updateRoleBody(businessId: bid, roleId: widget.role!.id, name: _name.text, description: _desc.text, chosen: chosen));
      } else {
        await repo.create(createRoleBody(businessId: bid, name: _name.text, description: _desc.text, chosen: chosen));
      }
      _roleChanged(ref);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(_editorDataProvider(widget.role?.id ?? ''));
    final data = async.value;
    if (data != null) _chosen ??= {...data.granted};
    final chosen = _chosen ?? <String>{};
    final ready = data != null && roleFormReady(_name.text, chosen.length);
    final groups = data == null ? const <String, List<PosPermission>>{} : groupPermissions(data.all);

    Widget groupCard(MapEntry<String, List<PosPermission>> g) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 8, bottom: 4), child: Text(g.key, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: context.primary))),
          for (final p in g.value)
            CheckboxListTile(
              dense: true,
              value: chosen.contains(p.id),
              onChanged: _busy ? null : (_) => setState(() => _chosen = togglePermission(chosen, p.id)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: p.description.isEmpty ? null : Text(p.description, style: TextStyle(fontSize: 12, color: tk.text3)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ]),
      ),
    );

    // the groups in two columns when the editor is wide, one column on a phone
    Widget groupsView() => LayoutBuilder(builder: (context, box) {
      final entries = groups.entries.toList();
      Widget col(List<MapEntry<String, List<PosPermission>>> es) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < es.length; i++) ...[if (i > 0) const SizedBox(height: 10), groupCard(es[i])]]);
      if (box.maxWidth < 560 || entries.length < 2) return col(entries);
      final half = (entries.length + 1) ~/ 2;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: col(entries.sublist(0, half))), const SizedBox(width: 10), Expanded(child: col(entries.sublist(half)))]);
    });

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Expanded(child: Text(context.str(_isEdit ? 'pos_posrolesscreen_edit_role' : 'pos_posrolesscreen_create_role'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))),
              IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str('pos_posrolesscreen_role_name'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3))),
                TextField(controller: _name, enabled: !_busy, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.str('pos_posrolesscreen_role_name_placeholder'))),
                Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(context.str('pos_posrolesscreen_description_optional'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3))),
                TextField(controller: _desc, enabled: !_busy, maxLines: 2, decoration: InputDecoration(hintText: context.str('pos_posrolesscreen_description_placeholder'))),
                const SizedBox(height: 18),
                if (data == null)
                  async.hasError
                      ? Column(children: [Text(context.str('pos_posroledetailscreen_permissions_failedtoLoadPermissions'), style: TextStyle(color: tk.danger, fontWeight: FontWeight.w700)), TextButton(onPressed: () => ref.invalidate(_editorDataProvider(widget.role?.id ?? '')), child: Text(context.str('pos_posstaffscreen_retry')))])
                      : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                else ...[
                  Row(children: [
                    Expanded(child: Text('${context.str('pos_posroledetailscreen_permissions_header_prefix')}${data.all.length}${context.str('pos_posroledetailscreen_permissions_header_suffix')}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tk.text3))),
                    Text('${chosen.length}${context.str('pos_posrolesscreen_selected_suffix')}', style: TextStyle(fontWeight: FontWeight.w700, color: context.primary)),
                  ]),
                  const SizedBox(height: 8),
                  groupsView(),
                ],
                if (_error != null) ...[const SizedBox(height: 10), PosErrorBox(_error!)],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (ready && !_busy) ? () => _save(chosen) : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                child: Text(context.str(_busy ? (_isEdit ? 'pos_posroledetailscreen_permissions_updating' : 'pos_posroledetailscreen_permissions_creating') : (_isEdit ? 'pos_posroledetailscreen_updateRole' : 'pos_posrolesscreen_create_role'))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}