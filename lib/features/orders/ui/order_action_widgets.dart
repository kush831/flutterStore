import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/order_detail_models.dart';
import '../logic/order_actions.dart';

final _lineBreak = RegExp(r'\\+n'); // the server texts contain a literal "\n"

// ── the buttons ──────────────────────────────────────────────────────────────

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.action, required this.busy, required this.onTap, this.onBrand = false});

  final OrderAction action;

  /// The action that is running (null = none). All buttons are disabled meanwhile.
  final String? busy;
  final ValueChanged<OrderAction> onTap;

  /// true = on the brand-colour header (white buttons).
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final brand = context.primary;
    final reject = OrderActions.isReject(action.action);
    final loading = OrderActions.isBusyFor(busy, action.action);
    final disabled = busy != null;

    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: reject ? (onBrand ? Colors.white : tk.danger) : (onBrand ? brand : Colors.white)),
    );
    final label = loading ? spinner : Text(action.text, maxLines: 1, overflow: TextOverflow.ellipsis);
    const size = Size(0, 48); // never "full width": these also sit in a Wrap

    if (reject) {
      final c = onBrand ? Colors.white : tk.danger;
      return OutlinedButton(
        onPressed: disabled ? null : () => onTap(action),
        style: OutlinedButton.styleFrom(minimumSize: size, foregroundColor: c, disabledForegroundColor: c.withValues(alpha: 0.5), side: BorderSide(color: c.withValues(alpha: disabled ? 0.4 : 1))),
        child: label,
      );
    }
    return FilledButton(
      onPressed: disabled ? null : () => onTap(action),
      style: FilledButton.styleFrom(
        minimumSize: size,
        backgroundColor: onBrand ? Colors.white : brand,
        foregroundColor: onBrand ? brand : Colors.white,
        disabledBackgroundColor: (onBrand ? Colors.white : brand).withValues(alpha: 0.55),
        disabledForegroundColor: (onBrand ? brand : Colors.white).withValues(alpha: 0.8),
      ),
      child: label,
    );
  }
}

/// Phone: fixed at the bottom of the screen.
class OrderActionBar extends StatelessWidget {
  const OrderActionBar({super.key, required this.actions, required this.busy, required this.onTap});

  final List<OrderAction> actions;
  final String? busy;
  final ValueChanged<OrderAction> onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(flex: OrderActions.isReject(actions[i].action) ? 1 : 2, child: ActionButton(action: actions[i], busy: busy, onTap: onTap)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide screens: in the brand header.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key, required this.actions, required this.busy, required this.onTap});

  final List<OrderAction> actions;
  final String? busy;
  final ValueChanged<OrderAction> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    alignment: WrapAlignment.end,
    children: [for (final a in actions) ActionButton(action: a, busy: busy, onTap: onTap, onBrand: true)],
  );
}

// ── dialogs ──────────────────────────────────────────────────────────────────

Future<bool> confirmAction(BuildContext context, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.str('common_allscreen_cancel_button'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: ctx.tk.danger, minimumSize: const Size(0, 44)),
          child: Text(ctx.str('common_allscreen_confirm_button')),
        ),
      ],
    ),
  );
  return ok == true;
}

enum AssignMode { automatic, manual }

Future<AssignMode?> showAssignModeDialog(BuildContext context) => showDialog<AssignMode>(
  context: context,
  builder: (ctx) {
    final tk = ctx.tk;
    Widget tile(IconData icon, String titleKey, String messageKey, AssignMode mode) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tk.sunken,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => Navigator.pop(ctx, mode),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: ctx.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: ctx.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.str(titleKey), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                      Text(ctx.str(messageKey), style: TextStyle(fontSize: 12.5, color: tk.text2, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AlertDialog(
      title: Text(ctx.str('orders_orderdetail_chooseHowToAssign').replaceAll(_lineBreak, '')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(Icons.auto_awesome_rounded, 'orders_ordersscreen_automatic_title', 'orders_ordersscreen_automatic_message', AssignMode.automatic),
            tile(Icons.person_search_rounded, 'orders_ordersscreen_manual_title', 'orders_ordersscreen_manual_message', AssignMode.manual),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.str('common_allscreen_cancel_button')))],
    );
  },
);

/// Verifies the pickup code with the server INSIDE the dialog, so a wrong code is shown here.
/// Returns the server's success message, or null when cancelled.
Future<String?> showPickupOtpDialog(BuildContext context, String orderId) =>
    showDialog<String>(context: context, barrierDismissible: false, builder: (_) => _PickupOtpDialog(orderId: orderId));

class _PickupOtpDialog extends ConsumerStatefulWidget {
  const _PickupOtpDialog({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_PickupOtpDialog> createState() => _PickupOtpDialogState();
}

class _PickupOtpDialogState extends ConsumerState<_PickupOtpDialog> {
  final _otp = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length < 4) {
      setState(() => _error = context.str('orders_ordersscreen_invalid_otp_message'));
      return;
    }
    setState(() => _error = null);
    try {
      final message = await ref.read(orderActionsProvider.notifier).perform(widget.orderId, OrderActions.pickup, otp: code);
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      final text = errorText(e, ref.read(stringsProvider));
      setState(() => _error = text.isEmpty ? context.str('orders_ordersscreen_invalid_otp_message') : text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final busy = ref.watch(orderActionsProvider) != null;
    return AlertDialog(
      title: Text(context.str('orders_ordersscreen_pickup_verification_button')),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.str('orders_orderdetail_pickup_verification_subtitle'), style: TextStyle(color: tk.text2, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: _otp,
              autofocus: true,
              enabled: !busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                hintText: context.str('orders_orderdetail_otp_label'),
                prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(context.str('common_allscreen_cancel_button'))),
        FilledButton(
          onPressed: busy ? null : _verify,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : Text(context.str('orders_ordersscreen_verify_otp_button')),
        ),
      ],
    );
  }
}

// ── manual driver selection ──────────────────────────────────────────────────

/// Returns the chosen driver ids, or null when closed.
Future<List<int>?> showDriverPicker(BuildContext context, {required String orderId, required int number}) =>
    showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DriverPicker(orderId: orderId, number: number),
    );

class _DriverPicker extends ConsumerStatefulWidget {
  const _DriverPicker({required this.orderId, required this.number});

  final String orderId;
  final int number;

  @override
  ConsumerState<_DriverPicker> createState() => _DriverPickerState();
}

class _DriverPickerState extends ConsumerState<_DriverPicker> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(driversProvider(widget.orderId));

    Widget message(IconData icon, String titleKey, {String? subtitleKey, VoidCallback? onRetry}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: tk.text3),
            const SizedBox(height: 12),
            Text(context.str(titleKey), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text1)),
            if (subtitleKey != null) ...[const SizedBox(height: 4), Text(context.str(subtitleKey), textAlign: TextAlign.center, style: TextStyle(color: tk.text2))],
            if (onRetry != null) ...[const SizedBox(height: 14), FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again')))],
          ],
        ),
      ),
    );

    final Widget body = async.when(
      loading: () => SkeletonPulse(child: Column(children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(height: 64, radius: 12))])),
      error: (_, _) => message(Icons.cloud_off_rounded, 'orders_orderdetail_drivers_failed_title', onRetry: () => ref.invalidate(driversProvider(widget.orderId))),
      data: (drivers) {
        if (drivers.isEmpty) return message(Icons.person_off_outlined, 'orders_orderdetail_drivers_no_available_title', subtitleKey: 'orders_orderdetail_drivers_no_available_subtitle');
        return ListView.separated(
          itemCount: drivers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = drivers[i];
            final on = _selected.contains(d.id);
            return Material(
              color: on ? context.primary.withValues(alpha: 0.08) : tk.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () => setState(() => on ? _selected.remove(d.id) : _selected.add(d.id)),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: on ? context.primary : tk.border, width: on ? 1.6 : 1)),
                  child: Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: d.image.isEmpty
                              ? ColoredBox(color: tk.sunken, child: Center(child: Text(d.name.isEmpty ? '·' : d.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text2))))
                              : CachedNetworkImage(imageUrl: d.image, fit: BoxFit.cover, memCacheWidth: 130, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
                            Row(
                              children: [
                                if (d.rating.isNotEmpty) ...[Icon(Icons.star_rounded, size: 15, color: tk.warning), const SizedBox(width: 2), Text(d.rating, style: TextStyle(fontSize: 12.5, color: tk.text2)), const SizedBox(width: 10)],
                                if (d.distance.isNotEmpty) Flexible(child: Text(d.distance, style: TextStyle(fontSize: 12.5, color: tk.text2))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? context.primary : tk.border),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${context.str('orders_selectdrivers_title')}  ·  ${context.str('orders_selectdrivers_order_prefix')}${widget.number}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
              const SizedBox(height: 2),
              Text(context.str('orders_orderdetail_select_drivers_hint'), style: TextStyle(fontSize: 13, color: tk.text2)),
              const SizedBox(height: 12),
              Expanded(child: body),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                child: Text('${context.str('orders_selectdrivers_assign_button')}${_selected.isEmpty ? '' : '  (${_selected.length})'}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}