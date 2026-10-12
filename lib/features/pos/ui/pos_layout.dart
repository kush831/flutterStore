import 'package:flutter/material.dart';

/// How wide a page may grow before it is centered (like a website).
const double kPosPageWidth = 960;

/// A content width from which cards go into two columns.
const double kPosWideBreak = 860;

/// A content width from which the Register shows the products and the cart side by side.
const double kPosTwoPaneBreak = 900;
const double kPosCartPaneWidth = 380;

/// Centers a page and keeps it from stretching across a wide screen.
class PosContent extends StatelessWidget {
  const PosContent({super.key, required this.child, this.maxWidth = kPosPageWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)),
  );
}

/// Cards in one column on a phone, and in two columns when there is room: the first half down the left, the rest down the right.
/// The spacer boxes between cards are dropped; the gap is added here.
class PosColumns extends StatelessWidget {
  const PosColumns({super.key, required this.children, this.gap = 12, this.breakAt = kPosWideBreak});

  final List<Widget> children;
  final double gap;
  final double breakAt;

  @override
  Widget build(BuildContext context) {
    final cards = [for (final c in children) if (!(c is SizedBox && c.child == null)) c];
    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]]]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < breakAt || cards.length < 2) return column(cards);
      final half = (cards.length + 1) ~/ 2;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: column(cards.sublist(0, half))), SizedBox(width: gap), Expanded(child: column(cards.sublist(half)))]);
    });
  }
}

/// Set by the two-pane Register: the cart is already on screen, so the "View cart" bar is not needed.
class PosTwoPane extends InheritedWidget {
  const PosTwoPane({super.key, required super.child});

  static bool active(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PosTwoPane>() != null;

  @override
  bool updateShouldNotify(PosTwoPane old) => false;
}

/// Set around a page that is shown as a panel (the cart beside the products): [PosPage] then draws a plain header, not a full screen.
class PosEmbedded extends InheritedWidget {
  const PosEmbedded({super.key, required super.child});

  static bool active(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PosEmbedded>() != null;

  @override
  bool updateShouldNotify(PosEmbedded old) => false;
}