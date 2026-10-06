import 'package:flutter/material.dart';

import 'design_tokens.dart';

enum PillTone { neutral, success, warning, danger, info, primary }

/// Small coloured label ("New", "Ready", "Cancelled", "Open") used across the whole app.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (fg, bg) = switch (tone) {
      PillTone.success => (tk.success, tk.successBg),
      PillTone.warning => (tk.warning, tk.warningBg),
      PillTone.danger => (tk.danger, tk.dangerBg),
      PillTone.info => (tk.info, tk.infoBg),
      PillTone.primary => (context.primary, context.primary.withValues(alpha: 0.12)),
      PillTone.neutral => (tk.text2, tk.sunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}