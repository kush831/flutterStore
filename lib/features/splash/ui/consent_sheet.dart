import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';

/// Resolves when the user taps "I Agree & Continue". There is no other way to close it.
Future<void> showConsentSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => const _ConsentSheet(),
);

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  static final _lineBreak = RegExp(r'\\+n'); // the server text contains a literal "\n"

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final items = <(IconData, String, String)>[
      (Icons.contacts_outlined, 'auth_welcomeview_consent_contact_list_phone_no', 'auth_welcomeview_consent_contact_list_phone_no_info'),
      (Icons.mail_outline_rounded, 'auth_welcomeview_consent_email_id', 'auth_welcomeview_consent_email_id_info'),
      (Icons.image_outlined, 'auth_welcomeview_consent_image_information', 'auth_welcomeview_consent_image_information_info'),
    ];

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.str('auth_welcomeview_consent_dialog_title'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 6),
              Text(context.str('auth_welcomeview_consent_dialog_subtitle').replaceAll(_lineBreak, '\n'),
                  style: TextStyle(color: tk.text2, height: 1.4)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (icon, title, info) in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Radii.md)),
                              child: Icon(icon, size: 20, color: context.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.str(title), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                                  const SizedBox(height: 2),
                                  Text(context.str(info), style: TextStyle(fontSize: 13, color: tk.text2, height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(context.str('auth_welcomeview_consent_note'), style: TextStyle(fontSize: 12, color: tk.text3)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.str('auth_welcomeview_consent_agree_and_continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}