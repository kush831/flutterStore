import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/adaptive_page.dart';
import '../../core/design/design_tokens.dart';
import '../../core/router/routes.dart';
import '../../core/strings/missing_keys.dart';
import '../../core/strings/strings_controller.dart';

/// QA tool: open screens, then come here. Every key the UI asked for that the server does not have is listed.
/// Copy the list and send it to the backend team. (Dev / Preview builds only.)
class StringsDevPage extends ConsumerWidget {
  const StringsDevPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final s = ref.watch(stringsProvider);

    return ValueListenableBuilder<int>(
      valueListenable: MissingKeys.changes,
      builder: (context, _, _) {
        final keys = MissingKeys.sorted;
        return AdaptivePage(
          title: 'Strings',
          subtitle: 'Missing keys',
          fallbackRoute: Routes.home,
          scroll: true,
          maxWidth: 800,
          actions: [
            const OutlinedButton(onPressed: MissingKeys.clear, child: Text('Clear')),
            FilledButton(
              onPressed: keys.isEmpty
                  ? null
                  : () async {
                await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(keys)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${keys.length} keys copied')));
                }
              },
              child: const Text('Copy JSON'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'language: ${s.code}   source: ${s.source.name}   keys loaded: ${s.strings.length}',
                    style: TextStyle(color: tk.text2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: keys.isEmpty
                      ? Text('No missing keys so far.', style: TextStyle(color: tk.text2))
                      : SelectableText(keys.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}