import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/style_models.dart';
import '../data/styles_repository.dart';

/// Returns the server's message when the styles were saved, otherwise null.
Future<String?> showStylesSheet(BuildContext context, List<CuisineStyle> styles) {
  final view = _StylesSheet(styles: styles);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(context: context, barrierDismissible: false, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680), child: view)));
  }
  return showModalBottomSheet<String>(context: context, isScrollControlled: true, isDismissible: false, builder: (_) => view);
}

class _StylesSheet extends ConsumerStatefulWidget {
  const _StylesSheet({required this.styles});

  final List<CuisineStyle> styles;

  @override
  ConsumerState<_StylesSheet> createState() => _StylesSheetState();
}

class _StylesSheetState extends ConsumerState<_StylesSheet> {
  late Set<String> _chosen = {for (final s in widget.styles) if (s.checked) s.id};
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ref.read(stylesRepositoryProvider).save(widget.styles, _chosen);
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, ref.read(stringsProvider)); // inside the sheet: a snackbar would hide behind it
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(context.str('settings_selectstyles_selectStyle'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1))),
              if (_chosen.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(50)),
                  child: Text('${_chosen.length} ${context.str('settings_selectstyles_selected_count_badge')}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.primary)),
                ),
              IconButton(onPressed: _busy ? null : () => Navigator.pop(context), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded)),
            ]),
            Text(context.str('settings_selectstyles_subtitle'), style: TextStyle(color: tk.text2, height: 1.4)),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in widget.styles)
                      FilterChip(
                        label: Text(s.name),
                        selected: _chosen.contains(s.id),
                        showCheckmark: false,
                        onSelected: _busy ? null : (_) => setState(() => _chosen = toggleStyle(_chosen, s.id)),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: tk.danger, fontSize: 13)))]),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Text(context.str('settings_selectstyles_saveStyles')),
            ),
          ],
        ),
      ),
    );
  }
}