import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_page.dart';
import 'breakpoints.dart';
import 'design_tokens.dart';

class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.fallbackRoute,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;

  /// Where the back arrow goes when there is nothing to pop (a direct link).
  final String fallbackRoute;
  final Widget child;
  final List<Widget> actions;

  /// Phones only; wide screens put the action in [actions].
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (context.screen.isCompact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: Row(children: [
                  IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1))),
                  ...actions,
                ]),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }
    return AdaptivePage(title: title, fallbackRoute: fallbackRoute, actions: actions, child: child);
  }
}