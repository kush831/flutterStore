import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/styles_repository.dart';
import 'styles_sheet.dart';

/// The Styles card of the Store Profile (food stores only). Chips of the chosen styles and a pencil.
class StylesCard extends ConsumerWidget {
  const StylesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appPrefsProvider).isFood) return const SizedBox.shrink();
    final tk = context.tk;
    final async = ref.watch(stylesProvider);
    final all = async.value;
    final chosen = [for (final s in all ?? const []) if (s.checked) s];

    Future<void> edit() async {
      if (all == null) return;
      final message = await showStylesSheet(context, all);
      if (message == null || !context.mounted) return;
      ref.invalidate(stylesProvider);
      showAppSnack(context, message.isEmpty ? context.str('storedetails_storeprofile_stylesSaved') : message);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(context.str('settings_selectstyles_title'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
              IconButton(onPressed: all == null ? null : edit, tooltip: context.str('settings_selectstyles_selectStyle'), icon: Icon(Icons.edit_outlined, size: 20, color: tk.text2)),
            ]),
            const SizedBox(height: 4),
            if (all == null && !async.hasError)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 3))
            else if (all == null)
              Text(context.str('common_allscreen_something_went_wrong'), style: TextStyle(color: tk.text3))
            else if (chosen.isEmpty)
                Text(context.str('settings_selectstyles_subtitle'), style: TextStyle(color: tk.text3, height: 1.4))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in chosen)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(50)),
                      child: Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.primary)),
                    ),
                ]),
          ],
        ),
      ),
    );
  }
}