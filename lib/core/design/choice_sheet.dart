import 'package:flutter/material.dart';

import 'design_tokens.dart';

class ChoiceItem {
  const ChoiceItem(this.id, this.label);

  final String id;
  final String label;
}

Future<String?> showChoiceSheet(BuildContext context, {required String title, required List<ChoiceItem> items, String? selectedId}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final tk = ctx.tk;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in items)
                          ListTile(
                            onTap: () => Navigator.pop(ctx, c.id),
                            title: Text(c.label, style: TextStyle(fontWeight: c.id == selectedId ? FontWeight.w700 : FontWeight.w500)),
                            trailing: c.id == selectedId ? Icon(Icons.check_circle_rounded, color: ctx.primary) : null,
                            selected: c.id == selectedId,
                            selectedTileColor: ctx.primary.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );