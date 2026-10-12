import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../finance/ui/finance_widgets.dart'; // FinanceMessage, ListSkeleton: generic message and loading pieces
import '../data/pos_permission.dart';
import '../data/pos_shift_models.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_logic.dart';
import '../logic/pos_shift_providers.dart';
import 'pos_terminal_editor.dart';
import 'pos_widgets.dart';

class PosTerminalsScreen extends ConsumerStatefulWidget {
  const PosTerminalsScreen({super.key});

  @override
  ConsumerState<PosTerminalsScreen> createState() => _PosTerminalsScreenState();
}

class _PosTerminalsScreenState extends ConsumerState<PosTerminalsScreen> {
  bool _availableOnly = false;

  Future<void> _refresh() async {
    ref.invalidate(posTerminalProvider);
    try {
      await ref.read(posTerminalProvider.future);
    } catch (_) {} // the error shows on screen
  }

  Future<void> _add() async {
    if (await showTerminalEditor(context) != true || !mounted) return;
    ref.invalidate(posTerminalProvider);
    showAppSnack(context, context.str('pos_posterminalscreen_terminal_added_success'));
  }

  Future<void> _edit(PosTerminal t) async {
    if (await showTerminalEditor(context, terminal: t) != true || !mounted) return;
    ref.invalidate(posTerminalProvider);
    showAppSnack(context, context.str('pos_posterminalscreen_terminal_updated_success'));
  }

  Future<void> _delete(PosTerminal t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 36, color: ctx.tk.danger),
        title: Text(ctx.str('pos_posterminalscreen_delete_terminal_title')),
        content: Text('${ctx.str('pos_posterminalscreen_delete_message_prefix')}${t.name}${ctx.str('pos_posterminalscreen_delete_message_suffix')}', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('pos_posterminalscreen_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)), child: Text(ctx.str('pos_posterminalscreen_delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(posShiftRepositoryProvider).deleteTerminal(ref.read(posBusinessIdProvider), t.id);
      ref.invalidate(posTerminalProvider);
      if (mounted) showAppSnack(context, context.str('pos_posterminalscreen_terminal_deleted_success'));
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final canManage = ref.watch(posAuthProvider.select((s) => s.can(PosPerm.terminalManage)));
    final async = ref.watch(posTerminalProvider);
    final all = async.value;

    final Widget body;
    if (all == null) {
      body = async.hasError
          ? FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('pos_posterminalscreen_failed_to_load'), actionKey: 'pos_posterminalscreen_try_again', onAction: _refresh)
          : const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton());
    } else if (all.isEmpty) {
      body = FinanceMessage(
        icon: Icons.devices_other_outlined,
        title: context.str('pos_posterminalscreen_no_terminals_yet'),
        message: context.str('pos_posterminalscreen_empty_subtitle'),
        actionKey: canManage ? 'pos_posterminalscreen_add_terminal' : null,
        onAction: canManage ? () async => _add() : null,
      );
    } else {
      final stats = terminalStats(all);
      final shown = _availableOnly ? availableOnly(all) : all;
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            Expanded(child: PosStat(label: context.str('pos_posterminalscreen_total'), value: '${stats.total}')),
            const SizedBox(width: 10),
            Expanded(child: PosStat(label: context.str('pos_posterminalscreen_available'), value: '${stats.available}', color: tk.success)),
            const SizedBox(width: 10),
            Expanded(child: PosStat(label: context.str('pos_posterminalscreen_in_use'), value: '${stats.inUse}', color: tk.warning)),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(label: Text(context.str('pos_posterminalscreen_available_only')), selected: _availableOnly, onSelected: (v) => setState(() => _availableOnly = v)),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Text(context.str('pos_posterminalscreen_no_available_terminals'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
                const SizedBox(height: 6),
                Text(context.str('pos_posterminalscreen_all_in_use_message'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.4)),
                const SizedBox(height: 12),
                TextButton(onPressed: () => setState(() => _availableOnly = false), child: Text(context.str('pos_posterminalscreen_show_all_terminals'))),
              ]),
            )
          else
            for (final t in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _TerminalCard(t: t, canManage: canManage, onEdit: () => _edit(t), onDelete: () => _delete(t))),
        ],
      );
    }

    return PosPage(
      title: context.str('pos_posterminalscreen_terminals'),
      actions: [if (canManage) TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 20), label: Text(context.str('pos_posterminalscreen_add')))],
      child: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({required this.t, required this.canManage, required this.onEdit, required this.onDelete});

  final PosTerminal t;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget line(String key, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(TextSpan(children: [TextSpan(text: '${context.str(key)}: ', style: TextStyle(color: tk.text3)), TextSpan(text: value, style: TextStyle(color: tk.text2))]), style: const TextStyle(fontSize: 12.5)),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(t.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))),
              if (canManage) IconButton(onPressed: onEdit, tooltip: context.str('pos_posterminalscreen_edit'), icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
              if (canManage) IconButton(onPressed: t.isInUse ? null : onDelete, tooltip: context.str('pos_posterminalscreen_delete'), icon: Icon(Icons.delete_outline_rounded, size: 20, color: t.isInUse ? tk.text3 : tk.danger)),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              PosChip(context.str('pos_posterminalscreen_type_label', [titleCase(t.type)]), context.primary),
              PosChip(context.str(t.isActive ? 'pos_posterminalscreen_active' : 'pos_posterminalscreen_inactive'), t.isActive ? tk.success : tk.text3),
              if (t.isInUse) PosChip(context.str('pos_posterminalscreen_in_use'), tk.warning),
            ]),
            const SizedBox(height: 6),
            Text(t.code, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text2)),
            line('pos_posterminalscreen_device_id', t.deviceId),
            line('pos_posterminalscreen_location_note', t.locationNote),
            if (t.isInUse) line('pos_posterminalscreen_operator', t.inUseBy),
          ],
        ),
      ),
    );
  }
}