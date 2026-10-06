import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../splash/ui/brand_widgets.dart';

/// Fade and slide up when a screen opens.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
    child: child,
  );
}

/// Email | Phone switch.
class AuthSegmented extends StatelessWidget {
  const AuthSegmented({super.key, required this.isFirst, required this.firstLabel, required this.secondLabel, required this.onChanged});

  final bool isFirst;
  final String firstLabel;
  final String secondLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget seg(String label, bool value) {
      final selected = isFirst == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected ? tk.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: selected ? tk.border : Colors.transparent),
              ),
              child: Center(
                child: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? tk.text1 : tk.text2)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tk.sunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [seg(firstLabel, true), seg(secondLabel, false)]),
    );
  }
}

enum AuthTone { danger, warning }

class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.tone, required this.text, this.title, this.onClose});

  final AuthTone tone;
  final String text;
  final String? title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (fg, bg, icon) = tone == AuthTone.danger
        ? (tk.danger, tk.dangerBg, Icons.error_outline_rounded)
        : (tk.warning, tk.warningBg, Icons.info_outline_rounded);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
                Text(text, style: TextStyle(color: fg, height: 1.4)),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(onPressed: onClose, visualDensity: VisualDensity.compact, icon: Icon(Icons.close_rounded, size: 18, color: fg))
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}
/// A small label above a brand headline ("Secure Verification").
class BrandChip extends StatelessWidget {
  const BrandChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final on = onColor(Theme.of(context).colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: on.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(50)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: on),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(color: on, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
        ],
      ),
    );
  }
}

/// 1 column when narrow, 2 columns when there is room.
class AuthGrid extends StatelessWidget {
  const AuthGrid({super.key, required this.children, this.minColumnWidth = 230});

  final List<Widget> children;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 16.0;
      final cols = (box.maxWidth / minColumnWidth).floor().clamp(1, 2);
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: 16, children: [for (final c in children) SizedBox(width: w, child: c)]);
    },
  );
}