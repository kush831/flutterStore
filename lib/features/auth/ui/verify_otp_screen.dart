import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/recovery_controller.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

const _kLength = 4;
const _kResendSeconds = 60;

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Timer? _timer;
  int _left = _kResendSeconds;
  bool _wrong = false;
  bool _resending = false;
  String? _banner;

  @override
  void initState() {
    super.initState();
    final r = ref.read(recoveryProvider);
    if (r.identifier.isEmpty) {
      // opened directly or after a browser refresh: the flow starts again at step 1
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.forgotPassword);
      });
      return;
    }
    _startTimer();
    // demo servers ask for the code to be filled in (never in a production build)
    if (AppEnv.devTools && r.autoFill && r.otp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _code.text = r.otp);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _kResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  void _onChanged(String v) {
    setState(() {
      _wrong = false;
      _banner = null;
    });
    if (v.length == _kLength) _verify();
  }

  void _verify() {
    if (_code.text.length != _kLength) return;
    FocusScope.of(context).unfocus();
    if (ref.read(recoveryProvider.notifier).verify(_code.text)) {
      // replace: Back from the next step goes to step 1, not to a code that is already used
      context.pushReplacement(Routes.resetPassword);
      return;
    }
    setState(() => _wrong = true);
    _shake.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _code.clear();
      setState(() {});
      _focus.requestFocus();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _banner = null;
    });
    try {
      await ref.read(recoveryProvider.notifier).sendCode(ref.read(recoveryProvider).identifier);
      if (!mounted) return;
      _code.clear();
      setState(() => _resending = false);
      _startTimer();
      _focus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _banner = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  String get _timerText => '${(_left ~/ 60).toString()}:${(_left % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final r = ref.watch(recoveryProvider);
    final len = _code.text.length;
    final primary = context.primary;

    return AuthSplitScaffold(
      title: context.str('auth_verificationcode_verifyOtp'),
      subtitle: '${context.str('auth_verificationcode_enterOtpInstruction')} ${r.identifier}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 boxes drawn on top of ONE real text field: paste, SMS autofill and backspace all work
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value), 0), child: child),
            child: Stack(
              children: [
                Opacity(
                  opacity: 0.01,
                  child: TextField(
                    controller: _code,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    enableInteractiveSelection: false,
                    showCursor: false,
                    maxLength: _kLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_kLength)],
                    onChanged: _onChanged,
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                    style: const TextStyle(height: 2.2),
                  ),
                ),
                IgnorePointer(
                  child: Row(
                    children: [
                      for (var i = 0; i < _kLength; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tk.surface,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(
                                color: _wrong ? tk.danger : (i == math.min(len, _kLength - 1) && _focus.hasFocus ? primary : tk.border),
                                width: _wrong || (i == math.min(len, _kLength - 1) && _focus.hasFocus) ? 1.8 : 1,
                              ),
                            ),
                            child: Text(i < len ? _code.text[i] : '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: tk.text1)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_wrong)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(context.str('error_invalid_otp'), style: TextStyle(color: tk.danger, fontSize: 13)),
            ),

          // dev / Preview builds only: the code the server returned
          if (AppEnv.devTools && r.otp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [Icon(Icons.bug_report_outlined, size: 16, color: tk.text3), const SizedBox(width: 6), SelectableText(r.otp, style: TextStyle(color: tk.text3, fontFamily: 'monospace'))]),
            ),

          const SizedBox(height: 18),
          if (_banner != null) ...[
            AuthBanner(tone: AuthTone.danger, text: _banner!),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: len == _kLength ? _verify : null,
            child: Text(context.str('auth_verificationcode_verifyOtp')),
          ),
          const SizedBox(height: 10),
          Center(
            child: _left > 0
                ? Text('${context.str('auth_verificationcode_resendCodeIn').trim()} $_timerText', style: TextStyle(color: tk.text2))
                : TextButton(
              onPressed: _resending ? null : _resend,
              child: _resending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.str('auth_verificationcode_resend_code_button')),
            ),
          ),
        ],
      ),
    );
  }
}