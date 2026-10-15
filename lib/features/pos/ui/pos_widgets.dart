import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/adaptive_page.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/pos_shift_logic.dart';
import '../logic/pos_staff_logic.dart';

/// A pushed POS page. Phone: an app bar, as before. Tablet and browser: the store app's website-style page header (AdaptivePage).
class PosPage extends StatelessWidget {
  const PosPage({super.key, required this.title, required this.child, this.actions, this.back = Routes.posMore, this.subtitle});

  final String title;
  final String? subtitle; // wide screens only: shown under the title
  final Widget child;
  final List<Widget>? actions;
  final String back; // where the arrow goes when there is nothing to go back to

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (context.screen.isCompact) {
      return Scaffold(
        backgroundColor: tk.canvas,
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          leading: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go(back), icon: const Icon(Icons.arrow_back_rounded)),
        ),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child))),
      );
    }
    final page = AdaptivePage(title: title, subtitle: subtitle, actions: actions ?? const [], fallbackRoute: back, child: child);
    // inside the POS frame the Scaffold is already there; on a page outside it, this one supplies it
    return Scaffold.maybeOf(context) != null ? Material(color: tk.canvas, child: page) : Scaffold(backgroundColor: tk.canvas, body: page);
  }
}

/// "08 Oct 2026  10:42" from the server's time text (shown as written when it cannot be read).
String posDateTime(BuildContext context, String raw) {
  final d = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (d == null) return raw;
  final loc = MaterialLocalizations.of(context);
  final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
  return '${loc.formatShortDate(d.toLocal())}  ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(d.toLocal()), alwaysUse24HourFormat: h24)}';
}

/// A small coloured pill.
class PosChip extends StatelessWidget {
  const PosChip(this.text, this.color, {super.key});

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

/// A label over a value, in a bordered card (counters, stats).
class PosStat extends StatelessWidget {
  const PosStat({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: tk.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color ?? tk.text1))),
        ],
      ),
    );
  }
}

/// An error line inside a sheet or form (a snackbar would hide behind a sheet).
class PosErrorBox extends StatelessWidget {
  const PosErrorBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tk.dangerBg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: tk.danger), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: tk.danger, fontSize: 13)))]),
    );
  }
}

Color cashStatusColor(BuildContext context, CashStatus s) {
  final tk = context.tk;
  return switch (s) {
    CashStatus.balanced => tk.success,
    CashStatus.surplus => tk.info,
    CashStatus.shortage => tk.danger,
  };
}

/// A member's avatar: the initials on the color the server chose (or the brand color).
class PosAvatar extends StatelessWidget {
  const PosAvatar({super.key, required this.initials, this.colorHex = '', this.radius = 22});

  final String initials;
  final String colorHex;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final v = parseHexColor(colorHex);
    final c = v == null ? context.primary : Color(v);
    return CircleAvatar(radius: radius, backgroundColor: c.withValues(alpha: 0.16), child: Text(initials, style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.72, color: c)));
  }
}

/// The status of a staff member: its words from the status, its color too.
class PosStaffStatusChip extends StatelessWidget {
  const PosStaffStatusChip({super.key, required this.status, this.serverText = ''});

  final String status;
  final String serverText;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final s = staffStatusOf(status);
    final c = switch (s) {
      StaffStatus.active => tk.success,
      StaffStatus.onBreak => tk.warning,
      _ => tk.text3,
    };
    final text = s == StaffStatus.unknown && serverText.isNotEmpty ? serverText : context.str(statusTextKey(s));
    return PosChip(text, c);
  }
}
/// A row whose children all take the height of the tallest one. Safe inside a scroll view,
/// where a plain Row with CrossAxisAlignment.stretch has no height to stretch to.
class PosEqualRow extends StatelessWidget {
  const PosEqualRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}