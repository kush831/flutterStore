import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
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
    final sessionAsync = ref.watch(posActiveSessionProvider);
    final s = sessionAsync.value;
    final terminalsAsync = ref.watch(posAvailableTerminalsProvider);
    final terminals = terminalsAsync.value ?? const <PosTerminal>[];
    final target = terminals.where((t) => t.id == _selectedId).firstOrNull;

    Widget label(String key) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3)));

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

    final Widget body;
    if (s == null || !s.isActive) {
      body = Center(child: sessionAsync.isLoading ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(32), child: Text(context.str('pos_posclosesessionscreen_session_data_not_available'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text2))));
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          label('pos_postransferterminalscreen_current_terminal'),
          Card(
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
          ),
          const SizedBox(height: 14),
          Row(children: [
            mode(Icons.sync_alt_rounded, 'pos_postransferterminalscreen_self_transfer', 'pos_postransferterminalscreen_i_can_still_log_in', !_force, () => setState(() => _force = false)),
            const SizedBox(width: 10),
            mode(Icons.admin_panel_settings_outlined, 'pos_posallsessionsscreen_force_transfer', 'pos_postransferterminalscreen_manager_override', _force, () => setState(() => _force = true)),
          ]),
          label('pos_postransferterminalscreen_move_to'),
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
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_outlined, size: 20, color: tk.success),
              const SizedBox(width: 10),
              Expanded(child: Text('${context.str('pos_postransferterminalscreen_preserved')}: ${context.str('pos_postransferterminalscreen_session_id_orders_payments_cash_count_staff_s')}', style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.4))),
            ]),
          ),
          if (_error != null) ...[const SizedBox(height: 14), PosErrorBox(_error!)],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (target != null && !_busy) ? () => _transfer(s, target) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
            child: _busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('pos_posallsessionsscreen_transferring'))])
                : Text(context.str(_force ? 'pos_posallsessionsscreen_force_transfer' : 'pos_postransferterminalscreen_transfer_terminal')),
          ),
        ],
      );
    }

    return PosPage(title: context.str('pos_postransferterminalscreen_transfer_terminal'), back: Routes.posSessions, child: body);
  }
}