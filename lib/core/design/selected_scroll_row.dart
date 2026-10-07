import 'package:flutter/material.dart';

/// A horizontal row that scrolls the selected child into view (centered) whenever the selection changes.
/// All children are built, so even one far off-screen can be reached.
class SelectedScrollRow extends StatefulWidget {
  const SelectedScrollRow({super.key, required this.padding, required this.selectedIndex, required this.children});

  final EdgeInsets padding;
  final int selectedIndex; // -1 = nothing selected
  final List<Widget> children;

  @override
  State<SelectedScrollRow> createState() => _SelectedScrollRowState();
}

class _SelectedScrollRowState extends State<SelectedScrollRow> {
  late List<GlobalKey> _keys = List.generate(widget.children.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(SelectedScrollRow old) {
    super.didUpdateWidget(old);
    if (_keys.length != widget.children.length) _keys = List.generate(widget.children.length, (_) => GlobalKey());
    if (old.selectedIndex != widget.selectedIndex || old.children.length != widget.children.length) _reveal();
  }

  void _reveal({bool animate = true}) {
    final i = widget.selectedIndex;
    if (i < 0 || i >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[i].currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5, duration: animate ? const Duration(milliseconds: 300) : Duration.zero, curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: widget.padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < widget.children.length; i++) KeyedSubtree(key: _keys[i], child: widget.children[i])],
    ),
  );
}