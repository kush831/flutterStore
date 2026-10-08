import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../logic/order_alarm.dart';
import '../logic/push_service.dart';

/// Wraps the whole app and draws the new-order banner above every screen.
class PushBannerHost extends ConsumerWidget {
  const PushBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(pushBannerProvider);
    return Stack(
      children: [
        child,
        if (e != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      elevation: 8,
                      color: context.primary,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        onTap: () => ref.read(pushServiceProvider).open(e),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(children: [
                            const Icon(Icons.notifications_active_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                if (e.title.isNotEmpty) Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                if (e.body.isNotEmpty) Text(e.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                              ]),
                            ),
                            TextButton(
                              onPressed: () => ref.read(pushServiceProvider).open(e),
                              style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: context.primary, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                              child: Text(context.str('orders_ordersscreen_view_button')),
                            ),
                            IconButton(
                              onPressed: () {
                                ref.read(orderAlarmProvider).stop(e.orderId); // closing the banner silences the alarm
                                ref.read(pushBannerProvider.notifier).hide();
                              },
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}