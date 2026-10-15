import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_repository.dart';
import '../data/pos_shift_models.dart';
import '../data/pos_shift_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_exit.dart';
import '../logic/pos_shift_logic.dart';
import '../logic/pos_shift_providers.dart';
import 'pos_widgets.dart';

/// Pick a free terminal, count the cash in the drawer, open the shift. Jetpack's "pos_open_session".
/// Phone: one column on the screen. Tablet and browser: one card in the middle, the terminals on the left and the cash on the right.
class PosOpenSessionScreen extends ConsumerStatefulWidget {
  const PosOpenSessionScreen({super.key});

  @override
  ConsumerState<PosOpenSessionScreen> createState() => _PosOpenSessionScreenState();
}

class _PosOpenSessionScreenState extends ConsumerState<PosOpenSessionScreen> {
  final _cash = TextEditingController();
  String? _selectedId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _open(PosTerminal terminal) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(posShiftRepositoryProvider).openSession(ref.read(posBusinessIdProvider), openingCash: _cash.text, terminal: terminal);
      ref.invalidate(posActiveSessionProvider); // the Active Session screen and the entry check read the new shift
      if (!mounted) return;
      context.go(Routes.pos);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
      });
      ref.invalidate(posAvailableTerminalsProvider); // someone may have taken the terminal meanwhile
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final wide = !context.screen.isCompact;
    final staff = ref.watch(posAuthProvider).staff;
    final currency = ref.watch(posCurrencyProvider);
    final async = ref.watch(posAvailableTerminalsProvider);
    final terminals = async.value ?? const <PosTerminal>[];
    final selected = terminals.where((t) => t.id == _selectedId).firstOrNull;
    final ready = selected != null && cashValid(_cash.text) && !_busy;

    final first = (staff?.name ?? '').trim().split(' ').first;
    final greeting = context.str('pos_possessionloginscreen_greeting_title', [first.isEmpty ? context.str('pos_possessionloginscreen_default_staff_name') : first]).replaceAll(RegExp(r'\\+n'), '\n');

    Widget sectionLabel(String key, {Widget? trailing, double top = 22}) => Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Row(children: [Expanded(child: Text(context.str(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3))), ?trailing]),
    );

    Widget terminalList() {
      if (async.isLoading && async.value == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
      if (async.hasError && async.value == null) {
        return Column(children: [Text(errorText(async.error!, ref.read(stringsProvider)), style: TextStyle(color: tk.text2)), TextButton(onPressed: () => ref.invalidate(posAvailableTerminalsProvider), child: Text(context.str('pos_posterminalscreen_try_again')))]);
      }
      if (terminals.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
          child: Column(children: [
            Text(context.str('pos_posterminalscreen_no_available_terminals'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
            const SizedBox(height: 6),
            Text(context.str('pos_posterminalscreen_all_in_use_message'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.4)),
          ]),
        );
      }
      return Column(children: [
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
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.desktop_windows_outlined, color: context.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1)),
                      Text([t.code, t.locationNote].where((s) => s.isNotEmpty).join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: tk.text2)),
                    ]),
                  ),
                  Icon(t.id == _selectedId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: t.id == _selectedId ? context.primary : tk.border),
                ]),
              ),
            ),
          ),
      ]);
    }

    final availableChip = terminals.isEmpty ? null : PosChip(context.str('pos_possessionloginscreen_available_count', [terminals.length]), tk.success);

    final cashField = TextField(
      controller: _cash,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: (_) {
        if (ready) _open(selected);
      },
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      decoration: InputDecoration(prefixText: currency.isEmpty ? null : '$currency ', hintText: context.str('pos_posdashboardscreen_shift_opening')),
    );

    final errorBox = _error == null ? null : PosErrorBox(_error!);
    final readyChip = ready ? Padding(padding: const EdgeInsets.only(bottom: 10), child: Center(child: PosChip(context.str('pos_possessionloginscreen_ready_to_open'), tk.success))) : null;

    final openButton = FilledButton(
      onPressed: ready ? () => _open(selected) : null,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
      child: _busy
          ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('pos_possessionloginscreen_opening'))])
          : Text(context.str('pos_possessionloginscreen_open_and_enter')),
    );

    final notes = Column(children: [
      Text(context.str('pos_possessionloginscreen_disclaimer'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: tk.text3)),
      const SizedBox(height: 4),
      Text(context.str('pos_possessionloginscreen_step_hint'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: tk.text3)),
    ]);

    final logout = TextButton.icon(onPressed: _busy ? null : () => posExit(context, ref), icon: const Icon(Icons.logout_rounded, size: 18), label: Text(context.str('pos_possessionloginscreen_logout')));
    final brandRow = Row(children: [
      Icon(Icons.point_of_sale_rounded, color: context.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(context.str('pos_possessionloginscreen_brand_subtitle'), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text1))),
      logout,
    ]);

    // ══ phone: exactly what it was ════════════════════════════════════════════
    if (!wide) {
      return Scaffold(
        backgroundColor: tk.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  brandRow,
                  const SizedBox(height: 14),
                  Text(greeting, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15, color: tk.text1)),
                  const SizedBox(height: 8),
                  Text(context.str('pos_possessionloginscreen_greeting_subtitle'), style: TextStyle(color: tk.text2, height: 1.45)),
                  sectionLabel('pos_possessionloginscreen_select_terminal', trailing: availableChip),
                  terminalList(),
                  sectionLabel('pos_posopensessionscreen_cash_in_drawer'),
                  cashField,
                  if (errorBox != null) ...[const SizedBox(height: 14), errorBox],
                  const SizedBox(height: 20),
                  ?readyChip,
                  openButton,
                  const SizedBox(height: 12),
                  notes,
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ══ tablet and browser: one card, two columns inside ══════════════════════
    final terminalSide = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionLabel('pos_possessionloginscreen_select_terminal', trailing: availableChip, top: 0),
      terminalList(),
    ]);

    final cashSide = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionLabel('pos_posopensessionscreen_cash_in_drawer', top: 0),
      cashField,
      if (errorBox != null) ...[const SizedBox(height: 14), errorBox],
      const SizedBox(height: 20),
      ?readyChip,
      openButton,
      const SizedBox(height: 12),
      notes,
    ]);

    return Scaffold(
      backgroundColor: tk.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                  child: LayoutBuilder(builder: (context, box) {
                    final two = box.maxWidth >= 560;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      brandRow,
                      const SizedBox(height: 14),
                      Text(greeting, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15, color: tk.text1)),
                      const SizedBox(height: 8),
                      Text(context.str('pos_possessionloginscreen_greeting_subtitle'), style: TextStyle(color: tk.text2, height: 1.45)),
                      const SizedBox(height: 24),
                      if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: terminalSide), const SizedBox(width: 24), Expanded(child: cashSide)]) else ...[terminalSide, const SizedBox(height: 16), cashSide],
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}