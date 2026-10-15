import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
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

/// The terminals of the store. Phone: cards in one column, "Add" in the app bar. Tablet and browser: the store app's page
/// header with an "Add terminal" button, the counters in a row, and the terminals in a grid of cards.
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
    final wide = !context.screen.isCompact;
    final canManage = ref.watch(posAuthProvider.select((s) => s.can(PosPerm.terminalManage)));
    final async = ref.watch(posTerminalProvider);
    final all = async.value;
    final title = context.str('pos_posterminalscreen_terminals');

    // the page around the body: an app bar on a phone, the store's page header on a tablet and a browser
    Widget page(Widget child, {List<Widget> actions = const []}) => wide
        ? AdaptivePage(title: title, subtitle: context.str('pos_posterminalscreen_subtitle'), actions: actions, child: child)
        : PosPage(title: title, actions: actions, child: RefreshIndicator(onRefresh: _refresh, child: child));

    final addButton = !canManage
        ? null
        : (wide
        ? FilledButton.icon(onPressed: _add, style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.add_rounded, size: 20), label: Text(context.str('pos_posterminalscreen_add_terminal')))
        : TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 20), label: Text(context.str('pos_posterminalscreen_add'))));
    final actions = [?addButton];

    // ── not here yet, failed, or empty ───────────────────────────────────────
    if (all == null) {
      return page(
        async.hasError
            ? FinanceMessage(icon: Icons.cloud_off_rounded, title: context.str('pos_posterminalscreen_failed_to_load'), actionKey: 'pos_posterminalscreen_try_again', onAction: _refresh)
            : const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ListSkeleton()),
        actions: actions,
      );
    }
    if (all.isEmpty) {
      return page(
        FinanceMessage(
          icon: Icons.devices_other_outlined,
          title: context.str('pos_posterminalscreen_no_terminals_yet'),
          message: context.str('pos_posterminalscreen_empty_subtitle'),
          actionKey: canManage ? 'pos_posterminalscreen_add_terminal' : null,
          onAction: canManage ? () async => _add() : null,
        ),
        actions: actions,
      );
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    final stats = terminalStats(all);
    final shown = _availableOnly ? availableOnly(all) : all;

    final counters = <Widget>[
      PosStat(label: context.str('pos_posterminalscreen_total'), value: '${stats.total}'),
      PosStat(label: context.str('pos_posterminalscreen_available'), value: '${stats.available}', color: tk.success),
      PosStat(label: context.str('pos_posterminalscreen_in_use'), value: '${stats.inUse}', color: tk.warning),
    ];

    final filter = Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilterChip(label: Text(context.str('pos_posterminalscreen_available_only')), selected: _availableOnly, onSelected: (v) => setState(() => _availableOnly = v)),
    );

    final noneAvailable = Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Text(context.str('pos_posterminalscreen_no_available_terminals'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1)),
        const SizedBox(height: 6),
        Text(context.str('pos_posterminalscreen_all_in_use_message'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.4)),
        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() => _availableOnly = false), child: Text(context.str('pos_posterminalscreen_show_all_terminals'))),
      ]),
    );

    Widget card(PosTerminal t) => _TerminalCard(t: t, canManage: canManage, onEdit: () => _edit(t), onDelete: () => _delete(t));

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [for (var i = 0; i < counters.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: counters[i])]]),
          const SizedBox(height: 12),
          filter,
          const SizedBox(height: 8),
          if (shown.isEmpty) noneAvailable else for (final t in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: card(t)),
        ],
      );
      return page(body, actions: actions);
    }

    // ══ tablet and browser: the terminals in a grid of cards ══════════════════
    final body = LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 980 ? 3 : (box.maxWidth >= 620 ? 2 : 1);
      final rows = (shown.length / cols).ceil();
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PosEqualRow(children: [for (var i = 0; i < counters.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: counters[i])]]),
            const SizedBox(height: 16),
            filter,
            const SizedBox(height: 12),
            if (shown.isEmpty)
              noneAvailable
            else
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PosEqualRow(children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: 12),
                      Expanded(child: r * cols + c < shown.length ? card(shown[r * cols + c]) : const SizedBox.shrink()),
                    ],
                  ]),
                ),
          ],
        ),
      );
    });
    return page(body, actions: actions);
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
              Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))),
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