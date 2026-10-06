import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/password_rules.dart';
import '../logic/recovery_controller.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;
  bool _tried = false; // after the first submit, unmet rules turn red
  String? _pwError;
  String? _confirmError;
  String? _banner;

  @override
  void initState() {
    super.initState();
    if (!ref.read(recoveryProvider).verified) {
      // the code was not verified (direct link or browser refresh): start again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.forgotPassword);
      });
    }
  }

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final check = PasswordCheck.of(_pw.text);
    String? pwErr;
    String? confirmErr;
    if (_pw.text.isEmpty) pwErr = context.str('auth_resetpassword_password_required_error');
    if (_confirm.text != _pw.text) confirmErr = context.str('auth_resetpassword_password_mismatch_error');

    setState(() {
      _tried = true;
      _pwError = pwErr;
      _confirmError = confirmErr;
      _banner = null;
    });
    if (pwErr != null || confirmErr != null || !check.acceptable) return;

    setState(() => _busy = true);
    try {
      final message = await ref.read(recoveryProvider.notifier).resetPassword(_pw.text);
      if (!mounted) return;
      showAppSnack(context, message);
      context.go(Routes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final check = PasswordCheck.of(_pw.text);
    final matches = _confirm.text.isNotEmpty && _confirm.text == _pw.text;

    final barColor = switch (check.score) {
      <= 1 => tk.danger,
      2 => tk.warning,
      3 => tk.info,
      _ => tk.success,
    };

    Widget rule(String key, bool ok) {
      final bad = _tried && !ok;
      final color = ok ? tk.success : (bad ? tk.danger : tk.text3);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(context.str(key), style: TextStyle(fontSize: 13.5, color: ok ? tk.text1 : (bad ? tk.danger : tk.text2)))),
          ],
        ),
      );
    }

    return AuthSplitScaffold(
      title: context.str('auth_resetpassword_changePassword'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.str('auth_resetpassword_new_password_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _pw,
            enabled: !_busy,
            obscureText: !_show,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => setState(() => _pwError = null),
            decoration: InputDecoration(
              hintText: context.str('auth_resetpassword_new_password_placeholder'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              errorText: _pwError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              ),
            ),
          ),

          // strength: label + 4-segment bar (colour only: the server has no Weak/Strong texts)
          if (_pw.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              label: '${context.str('auth_resetpassword_passwordStrength')} ${check.score}/4',
              child: Row(
                children: [
                  Text(context.str('auth_resetpassword_passwordStrength'), style: TextStyle(fontSize: 12.5, color: tk.text2)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedContainer(
                              duration: Motion.fast,
                              height: 6,
                              decoration: BoxDecoration(color: i < check.score ? barColor : tk.border, borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.str('auth_resetpassword_passwordRequirements'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tk.text1)),
                const SizedBox(height: 6),
                rule('auth_resetpassword_atLeast8Characters', check.length8),
                rule('auth_resetpassword_oneUpperCaseLetter', check.upper),
                rule('auth_resetpassword_oneNumber', check.number),
                rule('auth_resetpassword_oneSpecialCharacter', check.special),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text(context.str('auth_resetpassword_confirm_password_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _confirm,
            enabled: !_busy,
            obscureText: !_show,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => setState(() => _confirmError = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.str('auth_resetpassword_confirm_password_placeholder'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              errorText: _confirmError ??
                  (_confirm.text.isNotEmpty && !matches ? context.str('auth_resetpassword_password_mismatch_error') : null),
            ),
          ),
          if (matches)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: tk.success),
                  const SizedBox(width: 6),
                  Text(context.str('auth_resetpassword_passwordMatch'), style: TextStyle(color: tk.success, fontSize: 13)),
                ],
              ),
            ),

          const SizedBox(height: 22),
          if (_banner != null) ...[
            AuthBanner(tone: AuthTone.danger, text: _banner!),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(context.str('auth_resetpassword_updatePasswordButton')),
          ),
        ],
      ),
    );
  }
}