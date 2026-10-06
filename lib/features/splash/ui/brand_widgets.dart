import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_env.dart';

/// Readable text colour on top of a brand colour.
Color onColor(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : const Color(0xFF111827);

/// Flat brand texture: two large soft circles behind the content (no gradients, no blur).
/// Flat brand texture: two large soft circles behind the content (no gradients, no blur).
/// The content decides the size (so it also works inside a scrolling column).
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final on = onColor(Theme.of(context).colorScheme.primary);
    Widget circle(double size, double alpha) => IgnorePointer(
      child: Container(width: size, height: size, decoration: BoxDecoration(color: on.withValues(alpha: alpha), shape: BoxShape.circle)),
    );
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough, // the child gets the same constraints as the backdrop (bounded or not)
        children: [
          PositionedDirectional(top: -140, start: -120, child: circle(380, 0.07)),
          PositionedDirectional(bottom: -180, end: -140, child: circle(440, 0.06)),
          child, // not positioned: it sets the size
        ],
      ),
    );
  }
}
/// The store logo from the configuration, or the first letter of the app name.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size, this.logoUrl = ''});

  final double size;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final on = onColor(brand);
    final initial = AppEnv.appName.trim().isEmpty ? '·' : AppEnv.appName.trim()[0].toUpperCase();
    final fallback = Center(
      child: Text(initial, style: TextStyle(color: brand, fontSize: size * 0.46, fontWeight: FontWeight.w800)),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: on, borderRadius: BorderRadius.circular(size * 0.28)),
      child: logoUrl.isEmpty
          ? fallback
          : Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
          memCacheWidth: (size * 3).round(),
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

/// Three dots that pulse one after the other.
class LoadingPulse extends StatefulWidget {
  const LoadingPulse({super.key, required this.color});

  final Color color;

  @override
  State<LoadingPulse> createState() => _LoadingPulseState();
}

class _LoadingPulseState extends State<LoadingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Opacity(
              opacity: 0.25 + 0.75 * (1 - ((_c.value - i * 0.2) % 1.0 - 0.5).abs() * 2).clamp(0.0, 1.0),
              child: Container(width: 9, height: 9, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
            ),
          ),
      ],
    ),
  );
}