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
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_models.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_shift_providers.dart';
import 'pos_widgets.dart';

/// Move the open shift to another terminal. Self Transfer: this terminal still works.
/// Force Transfer: it does not (Manager override). Both send the same request. Jetpack's "transfer_terminal".
/// Phone: one column. Tablet and browser: the store app's page header, this terminal and the choice on the left, the free terminals on the right.
class PosTransferScreen extends ConsumerStatefulWidget {
  const PosTransferScreen({super.key});

  @override
  ConsumerState<PosTransferScreen> createState() => _PosTransferScreenState();
}

class _PosTransferScreenState extends ConsumerState<PosTransferScreen> {
  bool _force = false;
  String? _selectedId;
  String? _error;
  bool _busy = false;

  Future<void> _transfer(PosActiveSession s, PosTerminal target) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(posShiftRepositoryProvider).forceTransfer(ref.read(posBusinessIdProvider), sessionId: s.id, terminalId: target.id, deviceId: target.deviceId);
      ref.invalidate(posActiveSessionProvider);
      ref.invalidate(posAvailableTerminalsProvider);
      ref.invalidate(posTerminalProvider);
      if (!mounted) return;
      if (message.isNotEmpty) showAppSnack(context, message);
      context.go(Routes.posSessions);
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
    final wide = !context.screen.isCompact;
    final sessionAsync = ref.watch(posActiveSessionProvider);
    final s = sessionAsync.value;
    final terminalsAsync = ref.watch(posAvailableTerminalsProvider);
    final terminals = terminalsAsync.value ?? const <PosTerminal>[];
    final target = terminals.where((t) => t.id == _selectedId).firstOrNull;
    final title = context.str('pos_postransferterminalscreen_transfer_terminal');

    // top: how much room above the label (the phone keeps its 18, the two-column page starts flush)
    Widget label(String key, {double top = 18}) => Padding(padding: EdgeInsets.fromLTRB(4, top, 4, 8), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

    // ── no open shift: the same words on every width ─────────────────────────
    if (s == null || !s.isActive) {
      final Widget empty = Center(child: sessionAsync.isLoading ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(32), child: Text(context.str('pos_posclosesessionscreen_session_data_not_available'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text2))));
      return wide ? AdaptivePage(title: title, fallbackRoute: Routes.posSessions, child: empty) : PosPage(title: title, back: Routes.posSessions, child: empty);
    }

    // ── the pieces ───────────────────────────────────────────────────────────
    Widget mode(IconData icon, String titleKey, String subtitleKey, bool selected, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? context.primary.withValues(alpha: 0.07) : tk.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: selected ? context.primary : tk.border, width: selected ? 1.8 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: selected ? context.primary : tk.text3),
            const SizedBox(height: 8),
            Text(context.str(titleKey), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
            Text(context.str(subtitleKey), style: TextStyle(fontSize: 12, color: tk.text2)),
          ]),
        ),
      ),
    );

    final currentCard = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.desktop_windows_outlined, color: context.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.terminalName, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), if (s.deviceId.isNotEmpty) Text(s.deviceId, style: TextStyle(fontSize: 12.5, color: tk.text2))])),
          PosChip(context.str('pos_possessiondetailscreen_status_active'), tk.success),
        ]),
      ),
    );

    final modes = Row(children: [
      mode(Icons.sync_alt_rounded, 'pos_postransferterminalscreen_self_transfer', 'pos_postransferterminalscreen_i_can_still_log_in', !_force, () => setState(() => _force = false)),
      const SizedBox(width: 10),
      mode(Icons.admin_panel_settings_outlined, 'pos_posallsessionsscreen_force_transfer', 'pos_postransferterminalscreen_manager_override', _force, () => setState(() => _force = true)),
    ]);

    final terminalList = <Widget>[
      if (terminalsAsync.isLoading && terminalsAsync.value == null)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else if (terminals.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
          child: Column(children: [
            Text(context.str('pos_posterminalscreen_no_available_terminals'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
            const SizedBox(height: 6),
            Text(context.str('pos_posterminalscreen_all_in_use_message'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.4)),
          ]),
        )
      else
        for (final t in terminals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.lg),
              onTap: _busy ? null : () => setState(() => _selectedId = t.id),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.id == _selectedId ? context.primary.withValues(alpha: 0.07) : tk.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: t.id == _selectedId ? context.primary : tk.border, width: t.id == _selectedId ? 1.8 : 1),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)), Text([t.code, t.locationNote].where((x) => x.isNotEmpty).join('  ·  '), style: TextStyle(fontSize: 12.5, color: tk.text2))])),
                  Icon(t.id == _selectedId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: t.id == _selectedId ? context.primary : tk.border),
                ]),
              ),
            ),
          ),
    ];

    final preserved = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_outlined, size: 20, color: tk.success),
        const SizedBox(width: 10),
        Expanded(child: Text('${context.str('pos_postransferterminalscreen_preserved')}: ${context.str('pos_postransferterminalscreen_session_id_orders_payments_cash_count_staff_s')}', style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.4))),
      ]),
    );

    final errorBox = _error == null ? null : PosErrorBox(_error!);

    final submit = FilledButton(
      onPressed: (target != null && !_busy) ? () => _transfer(s, target) : null,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
      child: _busy
          ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('pos_posallsessionsscreen_transferring'))])
          : Text(context.str(_force ? 'pos_posallsessionsscreen_force_transfer' : 'pos_postransferterminalscreen_transfer_terminal')),
    );

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      final body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          label('pos_postransferterminalscreen_current_terminal'),
          currentCard,
          const SizedBox(height: 14),
          modes,
          label('pos_postransferterminalscreen_move_to'),
          ...terminalList,
          const SizedBox(height: 6),
          preserved,
          if (errorBox != null) ...[const SizedBox(height: 14), errorBox],
          const SizedBox(height: 20),
          submit,
        ],
      );
      return PosPage(title: title, back: Routes.posSessions, child: body);
    }

    // ══ tablet and browser ════════════════════════════════════════════════════
    final leftSide = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      label('pos_postransferterminalscreen_current_terminal', top: 0),
      currentCard,
      const SizedBox(height: 14),
      modes,
      const SizedBox(height: 14),
      preserved,
    ]);

    final rightSide = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      label('pos_postransferterminalscreen_move_to', top: 0),
      ...terminalList,
      if (errorBox != null) ...[const SizedBox(height: 6), errorBox],
      const SizedBox(height: 12),
      submit,
    ]);

    final body = LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth >= 700;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: two
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: leftSide), const SizedBox(width: 20), Expanded(child: rightSide)])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [leftSide, const SizedBox(height: 16), rightSide]),
          ),
        ),
      );
    });

    return AdaptivePage(
      title: title,
      subtitle: context.str('pos_possessiondashboardscreen_move_session_to_working_terminal'),
      fallbackRoute: Routes.posSessions,
      child: body,
    );
  }
}