import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/adaptive_page.dart';
import '../core/design/design_tokens.dart';

/// Stands in for every screen that is built in a later step.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.fallbackRoute, this.standalone = false});

  final String title;
  final String? fallbackRoute;

  /// true = full screen without the app frame (login, signup …).
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final where = GoRouterState.of(context).uri.toString();
    final body = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This screen is built in a later step.', style: TextStyle(color: tk.text2)),
            const SizedBox(height: 8),
            SelectableText(where, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );

    if (standalone) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: context.canPop() ? BackButton(onPressed: context.pop) : null,
        ),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: body))),
      );
    }
    return AdaptivePage(title: title, fallbackRoute: fallbackRoute, scroll: true, maxWidth: 800, child: body);
  }
}