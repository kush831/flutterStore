import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_language.dart';
import 'strings_controller.dart';
import 'strings_scope.dart';

/// Test widget for now. Step 6 shows the language NAMES from the configuration API.
class LanguageSelector extends ConsumerStatefulWidget {
  const LanguageSelector({super.key});

  @override
  ConsumerState<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends ConsumerState<LanguageSelector> {
  String? _busy;

  Future<void> _select(String code) async {
    setState(() => _busy = code);
    final ok = await ref.read(stringsProvider.notifier).setLanguage(code);
    if (!mounted) return;
    setState(() => _busy = null);
    if (!ok) {
      // shown in the language we stayed on
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.str('common_allscreen_something_went_wrong'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(stringsProvider.select((s) => s.code));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in AppLanguages.supported)
          ChoiceChip(
            label: Text(l.code.toUpperCase()),
            selected: l.code == current,
            avatar: _busy == l.code ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onSelected: _busy != null ? null : (_) => _select(l.code),
          ),
      ],
    );
  }
}