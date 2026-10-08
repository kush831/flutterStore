import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/ui/brand_widgets.dart';

/// The brand-color balance card, with an optional action on its right.
class BalanceHero extends StatelessWidget {
  const BalanceHero({super.key, required this.labelKey, required this.amount, this.action, this.loading = false});

  final String labelKey;
  final String amount;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SkeletonPulse(child: SkeletonBox(height: 100, radius: 16));
    final brand = context.primary;
    final on = onColor(brand);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.str(labelKey), style: TextStyle(fontSize: 13, color: on.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(amount, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: on))),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

class ListFooter extends StatelessWidget {
  const ListFooter({super.key, required this.hasMore, required this.loading, required this.failed, required this.onRetry});

  final bool hasMore;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) return Padding(padding: const EdgeInsets.all(12), child: Center(child: TextButton(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))));
    if (loading || hasMore) return const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))));
    return const SizedBox.shrink();
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(child: Column(children: [const SizedBox(height: 16), for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 70, radius: 16))]));
}

class FinanceMessage extends StatelessWidget {
  const FinanceMessage({super.key, required this.icon, required this.title, this.message, this.actionKey, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionKey;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tk.text1)),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.45))],
          if (onAction != null && actionKey != null) ...[const SizedBox(height: 16), FilledButton.tonal(onPressed: onAction, child: Text(context.str(actionKey!)))],
        ]),
      ),
    );
  }
}

/// A small coloured pill.
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => text.trim().isEmpty
      ? const SizedBox.shrink()
      : Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(50)),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
  );
}