import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';

/// The store's details as POS sees them. Read only, as in Jetpack.
class PosStoreProfileScreen extends ConsumerWidget {
  const PosStoreProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final async = ref.watch(posMerchantProvider);
    final m = async.value;

    final Widget body;
    if (m != null) {
      body = _Profile(m: m);
    } else if (async.hasError) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: tk.text3),
          const SizedBox(height: 14),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: () => ref.invalidate(posMerchantProvider), child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      body = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 120, radius: 16), SizedBox(height: 12), SkeletonBox(height: 150, radius: 16), SizedBox(height: 12), SkeletonBox(height: 200, radius: 16)]));
    }

    return Scaffold(
      backgroundColor: tk.canvas,
      appBar: AppBar(
        title: Text(context.str('pos_posmorescreen_item_store_profile_title')),
        leading: IconButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.posMore), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(posMerchantProvider);
          try {
            await ref.read(posMerchantProvider.future);
          } catch (_) {}
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [body]),
          ),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.m});

  final PosMerchant m;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    Widget card(String? titleKey, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (titleKey != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
            ...rows,
          ]),
        ),
      ),
    );

    Widget row(String labelKey, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(context.str(labelKey), style: TextStyle(color: tk.text3))),
        Expanded(child: SelectableText(value, style: TextStyle(color: tk.text1, fontWeight: FontWeight.w600, height: 1.35))),
      ]),
    );

    final fallback = Container(color: context.primary.withValues(alpha: 0.12), alignment: Alignment.center, child: Text(m.name.trim().isEmpty ? '·' : m.name.trim()[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.primary)));
    final acct = m.bankAccount;
    final masked = acct.length > 4 ? '•••• ${acct.substring(acct.length - 4)}' : acct; // never the full number on screen

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(width: 72, height: 72, child: m.image.isEmpty ? fallback : CachedNetworkImage(imageUrl: m.image, fit: BoxFit.cover, memCacheWidth: 220, placeholder: (_, _) => fallback, errorWidget: (_, _, _) => fallback)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                  if (m.segment.isNotEmpty) Text(m.segment, style: TextStyle(color: tk.text2)),
                  if (m.rating.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.star_rounded, size: 16, color: tk.warning), const SizedBox(width: 3), Text(m.rating, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1))])),
                ]),
              ),
            ]),
          ),
        ),
        card('storedetails_storeprofile_contact_info_title', [
          row('pos_posverifypinscreen_phone_number', m.phone),
          row('common_allscreen_email', m.email),
          row('storedetails_storeprofile_address', [m.address, m.landmark].where((s) => s.isNotEmpty).join('\n')),
        ]),
        card('pos_storeprofile_merchant', [
          row('pos_posverifypinscreen_role', m.ownerName),
          row('pos_posverifypinscreen_phone_number', m.ownerPhone),
          row('common_allscreen_email', m.ownerEmail),
        ]),
        card('storedetails_storeprofile_store_details_title', [
          row('common_allscreen_joined', m.joined),
          row('common_allscreen_email', m.contactEmail),
        ]),
        card('storedetails_storetimeslots_title', [
          for (final h in m.hours)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text(h.day, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1))),
                Text(h.isOpen ? '${h.open} – ${h.close}' : context.str('pos_storeprofile_closed'), style: TextStyle(color: h.isOpen ? tk.text2 : tk.danger)),
              ]),
            ),
        ]),
        card('pos_storeprofile_bank_title', [
          row('pos_storeprofile_bank_name', m.bankName),
          row('pos_storeprofile_bank_holder', m.bankHolder),
          row('pos_storeprofile_bank_account', masked),
        ]),
      ],
    );
  }
}