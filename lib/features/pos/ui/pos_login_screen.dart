import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/data/app_config.dart';
import '../../splash/logic/config_controller.dart';
import '../data/pos_repository.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_logic.dart';

class PosLoginScreen extends ConsumerStatefulWidget {
  const PosLoginScreen({super.key});

  @override
  ConsumerState<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends ConsumerState<PosLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  ConfigCountry? _country;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pinFocus.addListener(() => setState(() {})); // the active box follows the focus
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  // grep -n "countries" lib/features/splash/data/app_config.dart   if the list has another name
  List<ConfigCountry> get _countries => ref.read(appConfigProvider)?.countries ?? const [];
  ConfigCountry? get _current => _country ?? (_countries.isEmpty ? null : _countries.first);

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<ConfigCountry>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in _countries)
                ListTile(leading: Text(c.flag, style: const TextStyle(fontSize: 22)), title: Text(c.name), trailing: Text(c.dial), onTap: () => Navigator.pop(ctx, c)),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final c = _current;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(posRepositoryProvider).verifyPin(phone: phoneForLogin(c?.dial ?? '', _phone.text), countryId: c?.id ?? '', pin: _pin.text);
      await ref.read(posAuthProvider.notifier).signIn(token: r.token, raw: r.raw, staff: r.staff);
      if (!mounted) return;
      context.go(Routes.posStart); // the entry check decides: open shift → dashboard, otherwise Open Session
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider));
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = _current;
    final ready = posLoginReady(_phone.text, _pin.text) && !_busy;

    return Scaffold(
      backgroundColor: tk.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.welcome), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(width: 72, height: 72, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.point_of_sale_rounded, size: 36, color: context.primary)),
                  ),
                  const SizedBox(height: 18),
                  Text(context.str('pos_posverifypinscreen_staff_login'), textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: tk.text1)),
                  const SizedBox(height: 8),
                  Text(context.str('pos_posverifypinscreen_terminal_description'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45)),
                  const SizedBox(height: 28),
                  Text(context.str('pos_posverifypinscreen_phone_number'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)),
                  const SizedBox(height: 6),
                  Row(children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: (_busy || _countries.isEmpty) ? null : _pickCountry,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (c != null && c.flag.isNotEmpty) Text(c.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(c?.dial ?? '+', style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                          if (_countries.length > 1) Icon(Icons.arrow_drop_down_rounded, color: tk.text3),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        onChanged: (_) => setState(() => _error = null),
                        decoration: InputDecoration(hintText: context.str('pos_posverifypinscreen_mobile_number_placeholder')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  Text(context.str('pos_posverifypinscreen_4_digit_pin'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2)),
                  const SizedBox(height: 8),
                  _PinBoxes(controller: _pin, focus: _pinFocus, enabled: !_busy, hasError: _error != null, onChanged: () => setState(() => _error = null), onDone: ready ? _submit : null),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: ready ? _submit : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(context.str('pos_posverifypinscreen_verify_pin')),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${context.str('pos_posverifypinscreen_forgot_pin')} ', style: TextStyle(color: tk.text3)),
                        TextSpan(text: context.str('pos_posverifypinscreen_ask_manager'), style: TextStyle(color: tk.text1, fontWeight: FontWeight.w700)),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four boxes over one invisible text field: paste, autofill and the keyboard's "done" all work.
class _PinBoxes extends StatelessWidget {
  const _PinBoxes({required this.controller, required this.focus, required this.enabled, required this.hasError, required this.onChanged, required this.onDone});

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final bool hasError;
  final VoidCallback onChanged;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final text = controller.text;
    final active = focus.hasFocus ? text.length.clamp(0, 3).toInt() : -1;
    return GestureDetector(
      onTap: enabled ? focus.requestFocus : null,
      child: SizedBox(
        height: 62,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tk.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: hasError ? tk.danger : (i == active ? context.primary : tk.border), width: (i == active || hasError) ? 2 : 1),
                      ),
                      child: Text(i < text.length ? '•' : '', style: TextStyle(fontSize: 30, height: 1, color: tk.text1)),
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  enableInteractiveSelection: false,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onDone?.call(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}