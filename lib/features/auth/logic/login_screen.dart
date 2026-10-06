import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/data/app_config.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/brand_widgets.dart';
import '../logic/login_controller.dart';

const _kDemoPin = '12345678';
const _kSplitWidth = 900.0;

/// Phone / small tablet: brand header above the form.
/// Wide screens: the same split as the Welcome screen (brand panel + form).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isEmail = true;
  bool _showPassword = false;
  bool _showNotice = false;
  String _notice = ''; // the server's session-expired message ('' = default text)

  @override
  void initState() {
    super.initState();
    final n = ref.read(authControllerProvider).notice;
    if (n != null) {
      _showNotice = true;
      _notice = n;
      Future.microtask(() => ref.read(authControllerProvider.notifier).consumeNotice());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await ref.read(loginControllerProvider.notifier).submit(
      isEmail: _isEmail,
      identifier: _isEmail ? _email.text : _phone.text,
      password: _password.text,
    );
    if (ok) TextInput.finishAutofillContext();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.welcome);

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider) ?? const AppConfig();
    final split = MediaQuery.sizeOf(context).width >= _kSplitWidth;
    return split ? _buildSplit(context, cfg) : _buildCompact(context, cfg);
  }

  // ── phone ──────────────────────────────────────────────────────────────────
  Widget _buildCompact(BuildContext context, AppConfig cfg) {
    final tk = context.tk;
    final brand = context.primary;
    final on = onColor(brand);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: on == Colors.white ? Brightness.light : Brightness.dark,
        statusBarBrightness: on == Colors.white ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: tk.surface,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: ColoredBox(
                  color: brand,
                  child: BrandBackdrop(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, top + 12, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (context.canPop())
                                IconButton(
                                  onPressed: _back,
                                  style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
                                  icon: Icon(Icons.arrow_back_rounded, color: on),
                                )
                              else
                                BrandLogo(size: 40, logoUrl: cfg.logoUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(AppEnv.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on, fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(context.str('auth_loginscreen_welcomeBack'),
                              style: TextStyle(color: on, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                          const SizedBox(height: 6),
                          Text(context.str('auth_loginscreen_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: _Enter(child: _form(context, cfg)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── tablet landscape / desktop ─────────────────────────────────────────────
  Widget _buildSplit(BuildContext context, AppConfig cfg) {
    final tk = context.tk;
    final brand = context.primary;
    final on = onColor(brand);

    return Scaffold(
      backgroundColor: tk.surface,
      body: Row(
        children: [
          Expanded(
            flex: 10,
            child: ColoredBox(
              color: brand,
              child: BrandBackdrop(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BrandLogo(size: 44, logoUrl: cfg.logoUrl),
                            const SizedBox(width: 14),
                            Flexible(child: Text(AppEnv.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.w700))),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          context.str('auth_welcomeview_maintenance_retailManagementPlatform'),
                          style: TextStyle(color: on, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1),
                        ),
                        const SizedBox(height: 14),
                        Text(context.str('auth_welcomeview_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 16, height: 1.45)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: context.canPop()
                          ? IconButton(
                        onPressed: _back,
                        style: IconButton.styleFrom(side: BorderSide(color: tk.border)),
                        icon: Icon(Icons.arrow_back_rounded, color: tk.text1),
                      )
                          : const SizedBox(height: 48),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _Enter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.str('auth_loginscreen_welcomeBack'),
                                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: tk.text1)),
                                const SizedBox(height: 6),
                                Text(context.str('auth_loginscreen_signInToYourAccount'), style: TextStyle(fontSize: 15, color: tk.text2)),
                                const SizedBox(height: 24),
                                _form(context, cfg),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── the form (shared) ──────────────────────────────────────────────────────
  Widget _form(BuildContext context, AppConfig cfg) {
    final tk = context.tk;
    final st = ref.watch(loginControllerProvider);
    final ctrl = ref.read(loginControllerProvider.notifier);
    final showDemo = AppEnv.isPreview && ref.watch(appPrefsProvider).enteredPin == _kDemoPin;

    Widget title(String key) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(context.str(key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text1)),
    );

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showNotice) ...[
            _Banner(
              tone: _Tone.warning,
              title: context.str('auth_welcomeview_merchant_logout_title'),
              text: _notice.isEmpty ? context.str('auth_welcomeview_merchant_logout_message') : _notice,
              onClose: () => setState(() => _showNotice = false),
            ),
            const SizedBox(height: 16),
          ],

          _Segmented(
            isEmail: _isEmail,
            emailLabel: context.str('common_allscreen_email'),
            phoneLabel: context.str('common_allscreen_phone'),
            onChanged: (v) {
              ctrl.clearErrors();
              setState(() => _isEmail = v);
            },
          ),

          title(_isEmail ? 'auth_loginscreen_email_title' : 'auth_loginscreen_phone_title'),
          if (_isEmail)
            TextField(
              key: const ValueKey('email'),
              controller: _email,
              enabled: !st.busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onChanged: (_) => ctrl.clearErrors(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: InputDecoration(
                hintText: context.str('auth_loginscreen_email_placeholder'),
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                errorText: st.identifierError,
              ),
            )
          else
            TextField(
              key: const ValueKey('phone'),
              controller: _phone,
              enabled: !st.busy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              onChanged: (_) => ctrl.clearErrors(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: InputDecoration(
                hintText: context.str('auth_loginscreen_phone_placeholder'),
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                errorText: st.identifierError,
              ),
            ),

          title('auth_loginscreen_password_title'),
          TextField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !st.busy,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => ctrl.clearErrors(),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.str('auth_loginscreen_password_placeholder'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              errorText: st.passwordError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              ),
            ),
          ),

          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: st.busy ? null : () => context.push(Routes.forgotPassword),
              child: Text(context.str('auth_loginscreen_forgotPassword')),
            ),
          ),

          if (st.banner != null) ...[
            _Banner(tone: _Tone.danger, text: st.banner!),
            const SizedBox(height: 12),
          ],

          FilledButton(
            onPressed: st.busy ? null : _submit,
            child: st.busy
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                const SizedBox(width: 12),
                Flexible(child: Text(context.str('auth_loginscreen_signingIn'), overflow: TextOverflow.ellipsis)),
              ],
            )
                : Text(context.str('auth_loginscreen_sign_in_button')),
          ),

          if (cfg.signupEnabled) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.str('auth_loginscreen_sign_up_prompt').trim(), style: TextStyle(color: tk.text2, fontSize: 14)),
                TextButton(
                  onPressed: st.busy ? null : () => context.push(Routes.signup),
                  child: Text(context.str('auth_loginscreen_sign_up_action')),
                ),
              ],
            ),
          ],

          if (showDemo) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: st.busy ? null : () => context.push(Routes.demoLogin),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: Text(context.str('auth_demostoresview_login_button')),
            ),
          ],
        ],
      ),
    );
  }
}

// ── small widgets ────────────────────────────────────────────────────────────

/// Fade and slide up when the screen opens.
class _Enter extends StatelessWidget {
  const _Enter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
    child: child,
  );
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.isEmail, required this.emailLabel, required this.phoneLabel, required this.onChanged});

  final bool isEmail;
  final String emailLabel;
  final String phoneLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget seg(String label, bool value) {
      final selected = isEmail == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected ? tk.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: selected ? tk.border : Colors.transparent),
              ),
              child: Center(
                child: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? tk.text1 : tk.text2)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [seg(emailLabel, true), seg(phoneLabel, false)]),
    );
  }
}

enum _Tone { danger, warning }

class _Banner extends StatelessWidget {
  const _Banner({required this.tone, required this.text, this.title, this.onClose});

  final _Tone tone;
  final String text;
  final String? title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (fg, bg, icon) = tone == _Tone.danger
        ? (tk.danger, tk.dangerBg, Icons.error_outline_rounded)
        : (tk.warning, tk.warningBg, Icons.info_outline_rounded);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
                Text(text, style: TextStyle(color: fg, height: 1.4)),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(onPressed: onClose, visualDensity: VisualDensity.compact, icon: Icon(Icons.close_rounded, size: 18, color: fg))
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}