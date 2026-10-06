import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/preview_controller.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

class PreviewLoginScreen extends ConsumerStatefulWidget {
  const PreviewLoginScreen({super.key});

  @override
  ConsumerState<PreviewLoginScreen> createState() => _PreviewLoginScreenState();
}

class _PreviewLoginScreenState extends ConsumerState<PreviewLoginScreen> {
  final _pin = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await ref.read(previewControllerProvider.notifier).submit(_pin.text);
    if (ok && mounted) context.go(Routes.splash); // restarts consent / config / routing for this merchant
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(previewControllerProvider);
    final ctrl = ref.read(previewControllerProvider.notifier);

    return AuthSplitScaffold(
      title: context.str('auth_merchantlogin_header_title'),
      subtitle: context.str('auth_merchantlogin_preview_title'),
      brandTitleKey: 'auth_merchantlogin_preview_title',
      brandSubtitleKey: null,
      onBack: () => context.go(Routes.welcome),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pin,
            enabled: !st.busy,
            autofocus: true,
            obscureText: !_show,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => ctrl.clearErrors(),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.str('auth_merchantlogin_pin_placeholder'),
              prefixIcon: const Icon(Icons.key_rounded, size: 20),
              errorText: st.fieldError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (st.banner != null) ...[
            AuthBanner(tone: AuthTone.danger, text: st.banner!),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: st.busy ? null : _submit,
            child: st.busy
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                const SizedBox(width: 12),
                Flexible(child: Text(context.str('common_allscreen_verifying'), overflow: TextOverflow.ellipsis)),
              ],
            )
                : Text(context.str('common_allscreen_continue')),
          ),
        ],
      ),
    );
  }
}