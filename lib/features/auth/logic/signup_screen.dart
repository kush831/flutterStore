import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/data/app_config.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/brand_widgets.dart';
import '../logic/signup_controller.dart';
import '../logic/signup_validation.dart';

const _kSplitWidth = 900.0;

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _store = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _sName = TextEditingController();
  final _sEmail = TextEditingController();

  final _fStore = FocusNode();
  final _fName = FocusNode();
  final _fEmail = FocusNode();
  final _fPhone = FocusNode();
  final _fPassword = FocusNode();
  final _fConfirm = FocusNode();
  final _fSName = FocusNode();
  final _fSEmail = FocusNode();

  late final _termsTap = TapGestureRecognizer()..onTap = () => _openCms('terms');
  late final _privacyTap = TapGestureRecognizer()..onTap = () => _openCms('privacy');

  ConfigCountry? _country;
  String _segmentId = '';
  bool _agreed = false;
  bool _showPw = false;
  bool _defaultsSet = false;

  @override
  void initState() {
    super.initState();
    // opened by URL before the configuration was loaded
    if (ref.read(appConfigProvider) == null) Future.microtask(() => ref.read(configProvider.notifier).refresh());
  }

  @override
  void dispose() {
    for (final c in [_store, _name, _email, _phone, _password, _confirm, _sName, _sEmail]) {
      c.dispose();
    }
    for (final f in [_fStore, _fName, _fEmail, _fPhone, _fPassword, _fConfirm, _fSName, _fSEmail]) {
      f.dispose();
    }
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _applyDefaults(AppConfig cfg) {
    if (_defaultsSet) return;
    _defaultsSet = true;
    final region = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    _country = cfg.countries.where((c) => c.isoCode.toUpperCase() == region).firstOrNull ?? cfg.countries.firstOrNull;
    _segmentId = cfg.segments.firstOrNull?.id ?? ''; // the first segment is really selected
  }

  void _openCms(String word) {
    final page = ref.read(appConfigProvider)?.cmsPageLike(word);
    if (page != null) context.push(Routes.cms(page.slug));
  }

  bool _termsVisible(AppConfig cfg) => cfg.cmsPageLike('terms') != null || cfg.cmsPageLike('privacy') != null;

  SignupForm _form() => SignupForm(
    store: _store.text,
    segmentId: _segmentId,
    name: _name.text,
    email: _email.text,
    country: _country,
    phone: _phone.text,
    password: _password.text,
    confirm: _confirm.text,
    sponsorName: _sName.text,
    sponsorEmail: _sEmail.text,
    agreed: _agreed,
  );

  void _toLogin() => context.canPop() ? context.pop() : context.go(Routes.login);

  Future<void> _submit(AppConfig cfg) async {
    FocusScope.of(context).unfocus();
    final res = await ref.read(signupControllerProvider.notifier).submit(
      _form(),
      sponsor: cfg.sponsorOnSignup,
      termsRequired: _termsVisible(cfg),
    );
    if (!mounted) return;
    if (res.ok) {
      showAppSnack(context, res.message);
      context.go(Routes.login);
      return;
    }
    final errors = ref.read(signupControllerProvider).errors;
    final order = <(SignupField, FocusNode)>[
      (SignupField.store, _fStore),
      (SignupField.name, _fName),
      (SignupField.email, _fEmail),
      (SignupField.phone, _fPhone),
      (SignupField.password, _fPassword),
      (SignupField.confirm, _fConfirm),
      (SignupField.sponsorName, _fSName),
      (SignupField.sponsorEmail, _fSEmail),
    ];
    for (final (field, node) in order) {
      if (errors.containsKey(field)) {
        node.requestFocus();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    if (cfg == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _applyDefaults(cfg);

    final split = MediaQuery.sizeOf(context).width >= _kSplitWidth;
    return split ? _split(context, cfg) : _compact(context, cfg);
  }

  // ── phone ──────────────────────────────────────────────────────────────────
  Widget _compact(BuildContext context, AppConfig cfg) {
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
                      padding: EdgeInsets.fromLTRB(24, top + 12, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: _toLogin,
                            style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
                            icon: Icon(Icons.arrow_back_rounded, color: on),
                          ),
                          const SizedBox(height: 20),
                          Text(context.str('auth_signupscreen_title'),
                              style: TextStyle(color: on, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                          const SizedBox(height: 6),
                          Text(context.str('auth_signupscreen_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _formBody(context, cfg, columns: 1),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _toLogin, child: Text(context.str('auth_signupscreen_sign_in_prompt'), textAlign: TextAlign.center)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── tablet landscape / desktop ─────────────────────────────────────────────
  Widget _split(BuildContext context, AppConfig cfg) {
    final tk = context.tk;
    final brand = context.primary;
    final on = onColor(brand);

    return Scaffold(
      backgroundColor: tk.surface,
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: ColoredBox(
              color: brand,
              child: BrandBackdrop(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BrandLogo(size: 44, logoUrl: cfg.logoUrl),
                        const Spacer(),
                        Text(context.str('auth_signupscreen_title'),
                            style: TextStyle(color: on, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.8)),
                        const SizedBox(height: 12),
                        Text(context.str('auth_signupscreen_subtitle'), style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 15, height: 1.45)),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _toLogin,
                          style: TextButton.styleFrom(foregroundColor: on, padding: EdgeInsets.zero),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(context.str('auth_signupscreen_back_to_login')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.str('auth_signupscreen_fillInYourInformationBelow'),
                            style: TextStyle(fontSize: 15, color: tk.text2)),
                        const SizedBox(height: 8),
                        _formBody(context, cfg, columns: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── the form (shared) ──────────────────────────────────────────────────────
  Widget _formBody(BuildContext context, AppConfig cfg, {required int columns}) {
    final tk = context.tk;
    final st = ref.watch(signupControllerProvider);
    final ctrl = ref.read(signupControllerProvider.notifier);
    final termsVisible = _termsVisible(cfg);
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _password.text;

    Widget field({
      required SignupField id,
      required String label,
      required String hint,
      required TextEditingController c,
      required FocusNode node,
      IconData? icon,
      TextInputType? type,
      List<String>? autofill,
      List<TextInputFormatter>? formatters,
      String? prefixText,
      bool password = false,
      FocusNode? next,
      String? liveError,
    }) =>
        _Labeled(
          label: label,
          child: TextField(
            controller: c,
            focusNode: node,
            enabled: !st.busy,
            keyboardType: type,
            obscureText: password && !_showPw,
            autofillHints: autofill,
            inputFormatters: formatters,
            autocorrect: false,
            enableSuggestions: !password,
            textInputAction: next == null ? TextInputAction.done : TextInputAction.next,
            onChanged: (_) {
              ctrl.clearError(id);
              setState(() {});
            },
            onSubmitted: (_) => next?.requestFocus(),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefixText,
              prefixIcon: icon == null ? null : Icon(icon, size: 20),
              errorText: st.errors[id] ?? liveError,
              suffixIcon: password
                  ? IconButton(
                onPressed: () => setState(() => _showPw = !_showPw),
                icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              )
                  : null,
            ),
          ),
        );

    final c = _country;
    final maxPhone = c?.maxPhone ?? 0;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Store ────────────────────────────────────────────────────────
          _Section(context.str('storedetails_storeprofile_store_details_title')),
          _Grid(columns: columns, children: [
            field(
              id: SignupField.store,
              label: context.str('auth_signupscreen_store_name_title'),
              hint: context.str('auth_signupscreen_store_name_placeholder'),
              c: _store,
              node: _fStore,
              icon: Icons.storefront_outlined,
              next: _fName,
            ),
            _PickerField(
              label: context.str('auth_signupscreen_segmentType'),
              placeholder: context.str('auth_signupscreen_select_segment_title'),
              icon: Icons.category_outlined,
              value: cfg.segments.where((s) => s.id == _segmentId).firstOrNull?.name,
              error: st.errors[SignupField.segment],
              enabled: !st.busy,
              onTap: () async {
                final id = await _pickChoice(
                  context,
                  title: context.str('auth_signupscreen_select_segment_title'),
                  items: [for (final s in cfg.segments) _Choice(s.id, s.name)],
                  selectedId: _segmentId,
                );
                if (id != null) {
                  ctrl.clearError(SignupField.segment);
                  setState(() => _segmentId = id);
                }
              },
            ),
          ]),

          // ── Details ──────────────────────────────────────────────────────
          _Section(context.str('auth_signupscreen_yourDetails')),
          _Grid(columns: columns, children: [
            field(
              id: SignupField.name,
              label: context.str('auth_signupscreen_full_name_title'),
              hint: context.str('auth_signupscreen_full_name_placeholder'),
              c: _name,
              node: _fName,
              icon: Icons.person_outline_rounded,
              autofill: const [AutofillHints.name],
              next: _fEmail,
            ),
            field(
              id: SignupField.email,
              label: context.str('auth_signupscreen_email_title'),
              hint: context.str('auth_signupscreen_email_placeholder'),
              c: _email,
              node: _fEmail,
              icon: Icons.mail_outline_rounded,
              type: TextInputType.emailAddress,
              autofill: const [AutofillHints.email],
              next: _fPhone,
            ),
            _PickerField(
              label: context.str('auth_signupscreen_country'),
              placeholder: context.str('auth_signupscreen_selectCountry'),
              leadingText: c?.flag,
              value: c == null ? null : c.name,
              error: st.errors[SignupField.country],
              enabled: !st.busy,
              onTap: () async {
                final id = await _pickChoice(
                  context,
                  title: context.str('auth_signupscreen_selectCountry'),
                  searchHint: context.str('auth_signupscreen_searchCountry'),
                  emptyText: context.str('auth_signupscreen_noCountriesFound'),
                  items: [for (final k in cfg.countries) _Choice(k.id, k.name, leading: k.flag, trailing: k.dial)],
                  selectedId: c?.id,
                  searchable: true,
                );
                if (id != null) {
                  ctrl.clearError(SignupField.country);
                  setState(() => _country = cfg.countries.firstWhere((k) => k.id == id));
                }
              },
            ),
            field(
              id: SignupField.phone,
              label: context.str('auth_signupscreen_phone_title'),
              hint: context.str('auth_signupscreen_phone_placeholder'),
              c: _phone,
              node: _fPhone,
              type: TextInputType.phone,
              autofill: const [AutofillHints.telephoneNumber],
              prefixText: (c?.dial.isNotEmpty ?? false) ? '${c!.dial}  ' : null,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                if (maxPhone > 0) LengthLimitingTextInputFormatter(maxPhone),
              ],
              next: _fPassword,
            ),
          ]),

          // ── Security ─────────────────────────────────────────────────────
          _Section(context.str('pos_possecurityscreen_title')),
          _Grid(columns: columns, children: [
            field(
              id: SignupField.password,
              label: context.str('auth_signupscreen_password_title'),
              hint: context.str('auth_signupscreen_password_placeholder'),
              c: _password,
              node: _fPassword,
              icon: Icons.lock_outline_rounded,
              autofill: const [AutofillHints.newPassword],
              password: true,
              next: _fConfirm,
            ),
            field(
              id: SignupField.confirm,
              label: context.str('auth_signupscreen_confirm_password_title'),
              hint: context.str('auth_signupscreen_confirm_password_placeholder'),
              c: _confirm,
              node: _fConfirm,
              icon: Icons.lock_outline_rounded,
              autofill: const [AutofillHints.newPassword],
              password: true,
              next: cfg.sponsorOnSignup ? _fSName : null,
              liveError: mismatch ? context.str('auth_signupscreen_passwordNotMatch') : null,
            ),
          ]),

          // ── Sponsor (only when the server asks for it) ───────────────────
          if (cfg.sponsorOnSignup) ...[
            _Section(context.str('auth_signupscreen_sponsorInfo').trim()),
            _Grid(columns: columns, children: [
              field(
                id: SignupField.sponsorName,
                label: context.str('auth_signupscreen_sponsorName'),
                hint: context.str('auth_signupscreen_sponsorNamePlaceHolder'),
                c: _sName,
                node: _fSName,
                icon: Icons.person_add_alt_outlined,
                next: _fSEmail,
              ),
              field(
                id: SignupField.sponsorEmail,
                label: context.str('auth_signupscreen_sponsorEmail'),
                hint: context.str('auth_signupscreen_sponsorEmailPlaceHolder'),
                c: _sEmail,
                node: _fSEmail,
                icon: Icons.alternate_email_rounded,
                type: TextInputType.emailAddress,
              ),
            ]),
          ],

          const SizedBox(height: 22),

          if (st.banner != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: tk.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(st.banner!, style: TextStyle(color: tk.danger, height: 1.4))),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Terms + button ───────────────────────────────────────────────
          if (columns == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (termsVisible) Expanded(child: _terms(context, cfg, st)) else const Spacer(),
                const SizedBox(width: 24),
                SizedBox(width: 200, child: _submitButton(context, cfg, st, termsVisible)),
              ],
            )
          else ...[
            if (termsVisible) ...[_terms(context, cfg, st), const SizedBox(height: 14)],
            _submitButton(context, cfg, st, termsVisible),
          ],
        ],
      ),
    );
  }

  Widget _submitButton(BuildContext context, AppConfig cfg, SignupState st, bool termsVisible) => FilledButton(
    // like Jetpack: blocked only while the checkbox is visible and unticked
    onPressed: (st.busy || (termsVisible && !_agreed)) ? null : () => _submit(cfg),
    child: st.busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Text(context.str('auth_signupscreen_create_account_button')),
  );

  Widget _terms(BuildContext context, AppConfig cfg, SignupState st) {
    final tk = context.tk;
    final hasTerms = cfg.cmsPageLike('terms') != null;
    final hasPrivacy = cfg.cmsPageLike('privacy') != null;
    final link = TextStyle(color: context.primary, fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreed,
              onChanged: st.busy
                  ? null
                  : (v) {
                ref.read(signupControllerProvider.notifier).clearError(SignupField.terms);
                setState(() => _agreed = v ?? false);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: tk.text2, fontSize: 13.5, height: 1.4),
                    children: [
                      TextSpan(text: context.str('auth_signupscreen_continue_terms_prefix')),
                      if (hasTerms) TextSpan(text: context.str('auth_signupscreen_terms_text'), style: link, recognizer: _termsTap),
                      if (hasTerms && hasPrivacy) TextSpan(text: context.str('auth_signupscreen_continue_terms_middle')),
                      if (hasPrivacy) TextSpan(text: context.str('auth_signupscreen_privacy_text'), style: link, recognizer: _privacyTap),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (st.errors[SignupField.terms] != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48),
            child: Text(st.errors[SignupField.terms]!, style: TextStyle(color: tk.danger, fontSize: 12)),
          ),
      ],
    );
  }
}

// ── layout helpers ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: context.tk.text3),
    ),
  );
}

/// 1 column on a phone, 2 columns on a wide screen.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 16.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 16,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tk.text1)),
      ),
      child,
    ],
  );
}

// ── pickers (country, segment) ───────────────────────────────────────────────

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.icon,
    this.leadingText,
    this.error,
    this.enabled = true,
  });

  final String label;
  final String placeholder;
  final String? value;
  final IconData? icon;
  final String? leadingText;
  final String? error;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return _Labeled(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
            errorText: error,
            prefixIcon: (leadingText != null && leadingText!.isNotEmpty)
                ? Padding(padding: const EdgeInsets.all(14), child: Text(leadingText!, style: const TextStyle(fontSize: 18)))
                : (icon == null ? null : Icon(icon, size: 20)),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            value ?? placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, color: value == null ? tk.text3 : tk.text1),
          ),
        ),
      ),
    );
  }
}

class _Choice {
  const _Choice(this.id, this.label, {this.leading, this.trailing});

  final String id;
  final String label;
  final String? leading;
  final String? trailing;
}

Future<String?> _pickChoice(
    BuildContext context, {
      required String title,
      required List<_Choice> items,
      String? selectedId,
      bool searchable = false,
      String? searchHint,
      String? emptyText,
    }) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChoiceSheet(
        title: title,
        items: items,
        selectedId: selectedId,
        searchable: searchable,
        searchHint: searchHint,
        emptyText: emptyText,
      ),
    );

class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.searchable,
    this.searchHint,
    this.emptyText,
  });

  final String title;
  final List<_Choice> items;
  final String? selectedId;
  final bool searchable;
  final String? searchHint;
  final String? emptyText;

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((c) => c.label.toLowerCase().contains(q) || (c.trailing ?? '').contains(q)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 12),
              if (widget.searchable) ...[
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(hintText: widget.searchHint, prefixIcon: const Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: shown.isEmpty
                    ? Center(child: Text(widget.emptyText ?? '', style: TextStyle(color: tk.text2)))
                    : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    final selected = c.id == widget.selectedId;
                    return ListTile(
                      onTap: () => Navigator.pop(context, c.id),
                      leading: (c.leading == null || c.leading!.isEmpty) ? null : Text(c.leading!, style: const TextStyle(fontSize: 22)),
                      title: Text(c.label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded, color: context.primary)
                          : (c.trailing == null ? null : Text(c.trailing!, style: TextStyle(color: tk.text2))),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                      selected: selected,
                      selectedTileColor: context.primary.withValues(alpha: 0.08),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}