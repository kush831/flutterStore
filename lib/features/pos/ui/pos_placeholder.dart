import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';

/// A POS screen that is built in a later step. The navigation to it already works.
class PosPlaceholder extends StatelessWidget {
  const PosPlaceholder({super.key, required this.titleKey, this.pushed = false});

  final String titleKey;
  final bool pushed; // opened over the shell: shows a back arrow

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.construction_rounded, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(context.str(titleKey), textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)),
          const SizedBox(height: 6),
          Text(context.str('pos_placeholder_note'), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
        ]),
      ),
    );
    if (!pushed) return SafeArea(child: body);
    return Scaffold(
      backgroundColor: tk.canvas,
      appBar: AppBar(
        title: Text(context.str(titleKey)),
        leading: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.posMore), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: body,
    );
  }
}