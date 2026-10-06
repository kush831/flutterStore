import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../../core/utils/device_ip.dart';
import '../data/documents_repository.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

/// signup_status 3: the form is built from the fields the server asks for.
class StripeDocumentsScreen extends ConsumerStatefulWidget {
  const StripeDocumentsScreen({super.key});

  @override
  ConsumerState<StripeDocumentsScreen> createState() => _StripeDocumentsScreenState();
}

class _StripeDocumentsScreenState extends ConsumerState<StripeDocumentsScreen> {
  final _controllers = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _errors = <String, String>{};
  bool _busy = false;
  String? _banner;

  TextEditingController _c(String key) => _controllers.putIfAbsent(key, TextEditingController.new);
  FocusNode _f(String key) => _focus.putIfAbsent(key, FocusNode.new);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// The date picker returns the exact calendar day the user picked (Jetpack could shift it by a day).
  Future<void> _pickDate(StripeField f) async {
    final ctrl = _c(f.key);
    final now = DateTime.now();
    var initial = DateTime(now.year - 25, 1, 1);
    final p = ctrl.text.split('/');
    if (p.length == 3) {
      final d = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final y = int.tryParse(p[2]);
      if (d != null && m != null && y != null) initial = DateTime(y, m, d);
    }
    if (initial.isAfter(now)) initial = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() {
      ctrl.text = stripeDate(picked);
      _errors.remove(f.key);
    });
  }

  Future<void> _finish() => ref.read(authControllerProvider.notifier).setSignupStatus(0); // the router moves on

  Future<void> _submit(List<StripeField> fields) async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    final required = context.str('common_formvalidation_required_error');
    final errors = <String, String>{
      for (final f in fields)
        if (_c(f.key).text.trim().isEmpty) f.key: required,
    };
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _banner = null;
    });
    if (errors.isNotEmpty) {
      for (final f in fields) {
        if (errors.containsKey(f.key) && !f.isDate) {
          _f(f.key).requestFocus();
          break;
        }
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(documentsRepositoryProvider).submitStripe(
        {for (final f in fields) f.key: _c(f.key).text.trim()},
        ip: await deviceIp(),
      );
      await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  Widget _field(StripeField f, {required bool last}) {
    final tk = context.tk;
    final key = f.key.toLowerCase();
    final error = _errors[f.key];
    final enter = context.str('common_allscreen_enter').trim();

    final Widget input;
    if (f.isDate) {
      final value = _c(f.key).text;
      input = InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: _busy ? null : () => _pickDate(f),
        child: InputDecorator(
          decoration: InputDecoration(
            errorText: error,
            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            value.isEmpty ? context.str('stripeconnect_stripeconnect_selectDate') : value,
            style: TextStyle(fontSize: 16, color: value.isEmpty ? tk.text3 : tk.text1),
          ),
        ),
      );
    } else {
      final phone = key.contains('phone');
      final digits = key.contains('ssn');
      input = TextField(
        controller: _c(f.key),
        focusNode: _f(f.key),
        enabled: !_busy,
        keyboardType: phone ? TextInputType.phone : (digits ? TextInputType.number : TextInputType.text),
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        inputFormatters: [
          if (digits) FilteringTextInputFormatter.digitsOnly,
          if ((f.max ?? 0) > 0) LengthLimitingTextInputFormatter(f.max), // the field's own length limit
        ],
        onChanged: (_) {
          if (_errors.containsKey(f.key)) setState(() => _errors.remove(f.key));
        },
        onSubmitted: (_) => last ? FocusScope.of(context).unfocus() : FocusScope.of(context).nextFocus(),
        decoration: InputDecoration(
          hintText: '$enter ${f.label}',
          prefixIcon: Icon(phone ? Icons.phone_outlined : Icons.description_outlined, size: 20),
          errorText: error,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(f.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text1)),
        ),
        input,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(stripeFieldsProvider);

    Widget body;
    if (async.isLoading) {
      body = SkeletonPulse(
        child: AuthGrid(children: [for (var i = 0; i < 4; i++) const SkeletonBox(height: 56, radius: 12)]),
      );
    } else if (async.hasError) {
      body = Column(
        children: [
          AuthBanner(tone: AuthTone.danger, text: errorText(async.error!, ref.read(stringsProvider))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => ref.invalidate(stripeFieldsProvider), child: Text(context.str('common_allscreen_cancel_retry'))),
        ],
      );
    } else {
      final fields = async.requireValue;
      if (fields.isEmpty) {
        // a way forward when the server asks for nothing
        body = Column(
          children: [
            Icon(Icons.verified_rounded, size: 48, color: context.primary),
            const SizedBox(height: 12),
            Text(context.str('stripeconnect_stripeconnect_noDocumentsRequired'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 4),
            Text(context.str('stripeconnect_stripeconnect_youAreAllSet'), style: TextStyle(color: tk.text2)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _finish, child: Text(context.str('common_allscreen_continue'))),
          ],
        );
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthGrid(children: [for (var i = 0; i < fields.length; i++) _field(fields[i], last: i == fields.length - 1)]),
            const SizedBox(height: 22),
            if (_banner != null) ...[
              AuthBanner(tone: AuthTone.danger, text: _banner!),
              const SizedBox(height: 14),
            ],
            FilledButton(
              onPressed: _busy ? null : () => _submit(fields),
              child: _busy
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(context.str('common_allscreen_submitting'), overflow: TextOverflow.ellipsis)),
                ],
              )
                  : Text(context.str('stripeconnect_stripeconnect_submit_button')),
            ),
          ],
        );
      }
    }

    return AuthSplitScaffold(
      title: context.str('stripeconnect_stripeconnect_requiredDocuments'),
      subtitle: context.str('stripeconnect_stripeconnect_fillAllTheFieldsBelow'),
      brandTitleKey: 'stripeconnect_stripeconnect_stripeVerification',
      brandSubtitleKey: 'stripeconnect_stripeconnect_completeYourAccountSetup',
      badge: context.str('stripeconnect_stripeconnect_secureVerification'),
      badgeIcon: Icons.lock_rounded,
      formMaxWidth: 560,
      // back = sign out (the router would send a signed-in user straight back here)
      onBack: () => ref.read(authControllerProvider.notifier).signOut(),
      child: body,
    );
  }
}