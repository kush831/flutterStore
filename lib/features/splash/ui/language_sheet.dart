import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/config_controller.dart';

/// Language names come from the configuration API. Used on the splash (first run),
/// the welcome screen chip, and later More → Language.
Future<void> showLanguageSheet(BuildContext context, {bool dismissible = true}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: dismissible,
  enableDrag: dismissible,
  builder: (_) => const LanguageSheet(),
);

class LanguageSheet extends ConsumerStatefulWidget {
  const LanguageSheet({super.key});

  @override
  ConsumerState<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<LanguageSheet> {
  String? _busy;
  bool _failed = false;

  Future<void> _select(String code) async {
    setState(() {
      _busy = code;
      _failed = false;
    });
    final ok = await ref.read(stringsProvider.notifier).setLanguage(code);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = null;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final current = ref.watch(stringsProvider.select((s) => s.code));
    final languages = ref.watch(configProvider.select((s) => s.config))?.supportedLanguages ?? const [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.str('auth_welcomeview_maintenance_selectLanguage'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
            const SizedBox(height: 4),
            Text(context.str('auth_welcomeview_maintenance_choosePreferedLanguage'), style: TextStyle(color: tk.text2)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in languages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: l.locale == current ? context.primary.withValues(alpha: 0.10) : tk.sunken,
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.md),
                          onTap: _busy != null ? null : () => _select(l.locale),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: l.locale == current ? FontWeight.w700 : FontWeight.w500,
                                      color: l.locale == current ? context.primary : tk.text1,
                                    ),
                                  ),
                                ),
                                if (_busy == l.locale)
                                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                else if (l.locale == current)
                                  Icon(Icons.check_circle_rounded, color: context.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_busy != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.str('auth_welcomeview_maintenance_applyingLanguage'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.str('common_allscreen_something_went_wrong'), textAlign: TextAlign.center, style: TextStyle(color: tk.danger)),
              ),
          ],
        ),
      ),
    );
  }
}