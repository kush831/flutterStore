import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/adaptive_page.dart';
import '../../core/design/design_tokens.dart';
import '../../core/router/routes.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/strings/missing_keys.dart';
import '../../core/strings/strings_controller.dart';

/// Dev / Preview only. 1) reload the texts from the server, 2) find the real key for a text,
/// 3) see which keys the UI asked for that the server did not send.
class StringsDevPage extends ConsumerStatefulWidget {
  const StringsDevPage({super.key});

  @override
  ConsumerState<StringsDevPage> createState() => _StringsDevPageState();
}

class _StringsDevPageState extends ConsumerState<StringsDevPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final s = ref.watch(stringsProvider);
    final q = _q.trim().toLowerCase();
    final matches = q.length < 2
        ? const <MapEntry<String, String>>[]
        : s.strings.entries.where((e) => e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q)).take(60).toList();

    return ValueListenableBuilder<int>(
      valueListenable: MissingKeys.changes,
      builder: (context, _, _) {
        final missing = MissingKeys.sorted;
        return AdaptivePage(
          title: 'Strings',
          subtitle: 'Reload · find keys · missing keys',
          fallbackRoute: Routes.home,
          scroll: true,
          maxWidth: 800,
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

              // ── 1. reload from the server (throws the saved copy away) ──
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(appPrefsProvider).clearStringsCache();
                  ref.invalidate(stringsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reload strings from server'),
              ),
              const SizedBox(height: 12),

              // ── 2. find a key ──
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search the server strings (key or text), e.g. "orders"',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              if (q.length >= 2) ...[
                const SizedBox(height: 8),
                Card(
                  child: matches.isEmpty
                      ? Padding(padding: const EdgeInsets.all(16), child: Text('No match on the server.', style: TextStyle(color: tk.text2)))
                      : Column(
                    children: [
                      for (final e in matches)
                        ListTile(
                          dense: true,
                          title: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: SelectableText(e.key, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: e.key));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${e.key}')));
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],

              // ── 3. missing keys ──
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MISSING KEYS (${missing.length})',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: tk.text3),
                    ),
                  ),
                  TextButton(onPressed: MissingKeys.clear, child: const Text('Clear')),
                  FilledButton(
                    onPressed: missing.isEmpty
                        ? null
                        : () async {
                      await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(missing)));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${missing.length} keys copied')));
                      }
                    },
                    child: const Text('Copy JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: missing.isEmpty
                      ? Text('No missing keys so far.', style: TextStyle(color: tk.text2))
                      : SelectableText(missing.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}