import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'breakpoints.dart';
import 'design_tokens.dart';

/// Every screen uses this. Phone: native page with an app bar.
/// Tablet / desktop: website-style page (large title, subtitle, action buttons, centered content).
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 1200,
    this.scroll = false,
    this.fallbackRoute,
    this.onBack,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;

  /// Phone: app bar actions. Wide: buttons on the right of the page header.
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;

  /// true = the page scrolls as a whole (forms, details). false = the child scrolls itself (lists, tables).
  final bool scroll;

  /// Where "back" goes when the page was opened with go() and there is nothing to pop.
  final String? fallbackRoute;
  final VoidCallback? onBack;

  /// Phone only. On wide screens put the main action in [actions].
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final size = context.screen;
    final tk = context.tk;
    final pad = Breakpoints.padding(size);
    final canBack = onBack != null || context.canPop() || fallbackRoute != null;

    void back() {
      if (onBack != null) {
        onBack!();
      } else if (context.canPop()) {
        context.pop();
      } else if (fallbackRoute != null) {
        context.go(fallbackRoute!);
      }
    }

    Widget body(EdgeInsets padding) => scroll
        ? Scrollbar(
      child: SingleChildScrollView(
        padding: padding,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
        ),
      ),
    )
        : child;

    // ── Phone ────────────────────────────────────────────────────────────────
    if (size.isCompact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        appBar: AppBar(
          leading: canBack ? BackButton(onPressed: back) : null,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [...actions, const SizedBox(width: 4)],
        ),
        floatingActionButton: floatingActionButton,
        body: body(EdgeInsets.all(pad)),
      );
    }

    // ── Tablet / desktop ─────────────────────────────────────────────────────
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + pad * 2),
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
          child: Column(
            children: [
              Row(
                children: [
                  if (canBack) ...[
                    Tooltip(
                      message: MaterialLocalizations.of(context).backButtonTooltip,
                      child: IconButton(
                        onPressed: back,
                        style: IconButton.styleFrom(side: BorderSide(color: tk.border)),
                        icon: Icon(Icons.arrow_back_rounded, color: tk.text1),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tk.text1),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: TextStyle(fontSize: 14, color: tk.text2)),
                        ],
                      ],
                    ),
                  ),
                  for (final a in actions) ...[const SizedBox(width: 10), a],
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: body(const EdgeInsets.only(bottom: 40))),
            ],
          ),
        ),
      ),
    );
  }
}