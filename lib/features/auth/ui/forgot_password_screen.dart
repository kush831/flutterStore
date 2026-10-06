import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/recovery_controller.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _isEmail = true;
  bool _busy = false;
  String? _fieldError;
  String? _banner;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final id = (_isEmail ? _email : _phone).text.trim();

    String? error;
    if (id.isEmpty) {
      error = context.str(_isEmail ? 'auth_forgotpassword_email_required_error' : 'storedetails_storeprofile_phone_required');
    } else if (_isEmail && !_emailRe.hasMatch(id)) {
      error = context.str('auth_forgotpassword_email_invalid_error');
    }
    if (error != null) {
      setState(() {
        _fieldError = error;
        _banner = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _fieldError = null;
      _banner = null;
    });
    try {
      await ref.read(recoveryProvider.notifier).sendCode(id);
      if (!mounted) return;
      setState(() => _busy = false);
      context.push(Routes.verifyOtp);
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
    return AuthSplitScaffold(
      title: context.str('auth_forgotpassword_forgotPassword'),
      subtitle: context.str('auth_forgotpassword_info'),
      showStepTitleOnWide: false, // the brand panel already says it
      onBack: () {
        ref.read(recoveryProvider.notifier).clear();
        context.canPop() ? context.pop() : context.go(Routes.login);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSegmented(
            isFirst: _isEmail,
            firstLabel: context.str('common_allscreen_email'),
            secondLabel: context.str('common_allscreen_phone'),
            onChanged: (v) => setState(() {
              _isEmail = v;
              _fieldError = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 6),
            child: Text(
              context.str(_isEmail ? 'auth_forgotpassword_email_title' : 'auth_forgotpassword_phone_title'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (_isEmail)
            TextField(
              key: const ValueKey('email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onChanged: (_) => setState(() => _fieldError = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: context.str('auth_forgotpassword_email_placeholder'),
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                errorText: _fieldError,
              ),
            )
          else
            TextField(
              key: const ValueKey('phone'),
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              onChanged: (_) => setState(() => _fieldError = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: context.str('auth_forgotpassword_phone_placeholder'),
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                errorText: _fieldError,
              ),
            ),
          const SizedBox(height: 20),
          if (_banner != null) ...[
            AuthBanner(tone: AuthTone.danger, text: _banner!),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(context.str('auth_forgotpassword_sendVerificationCode')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () {
              ref.read(recoveryProvider.notifier).clear();
              context.canPop() ? context.pop() : context.go(Routes.login);
            },
            child: Text(context.str('auth_forgotpassword_back_to_login')),
          ),
        ],
      ),
    );
  }
}