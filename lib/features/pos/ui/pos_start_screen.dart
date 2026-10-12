import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../logic/pos_logic.dart';

/// Right after a POS sign-in or an app start inside POS: is a shift open? Dashboard if yes, Open Session if not.
class PosStartScreen extends ConsumerWidget {
  const PosStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<PosActiveSession?>>(posActiveSessionProvider, (_, next) {
      if (next case AsyncData(:final value)) context.go(posEntryRoute(value));
    });
    final async = ref.watch(posActiveSessionProvider); // keeps it alive while we wait
    final tk = context.tk;

    return Scaffold(
      backgroundColor: tk.canvas,
      body: Center(
        child: async.hasError
            ? Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: tk.text3),
          const SizedBox(height: 14),
          Text(context.str('common_allscreen_something_went_wrong'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(posActiveSessionProvider), child: Text(context.str('common_allscreen_try_again'))),
        ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.point_of_sale_rounded, size: 44, color: context.primary),
          const SizedBox(height: 18),
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
          const SizedBox(height: 14),
          Text(context.str('pos_posverifypinscreen_merchant_pos'), style: TextStyle(color: tk.text2)),
        ]),
      ),
    );
  }
}