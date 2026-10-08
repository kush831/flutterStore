import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../home/ui/home_format.dart';
import '../data/store_models.dart';
import '../logic/store_providers.dart';

class StoreProfileScreen extends ConsumerWidget {
  const StoreProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(storeProfileProvider);
    try {
      await ref.read(storeProfileProvider.future);
    } catch (_) {} // the error shows on screen
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final async = ref.watch(storeProfileProvider);
    final p = async.value;
    final isOpen = ref.watch(dashboardProvider.select((s) => s.isOpen));

    final Widget body;
    if (p != null) {
      body = _Body(p: p, isOpen: isOpen ?? false, wide: wide);
    } else if (async.hasError) {
      body = Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
            const SizedBox(height: 10),
            Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: () => _refresh(ref), child: Text(context.str('common_allscreen_try_again'))),
          ]),
        ),
      );
    } else {
      body = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 130, radius: 16), SizedBox(height: 12), SkeletonBox(height: 120, radius: 16), SizedBox(height: 12), SkeletonBox(height: 100, radius: 16)]));
    }

    return SubPage(
      title: context.str('storedetails_storeprofile_screen_title'),
      fallbackRoute: Routes.more,
      actions: [
        if (p != null)
          wide
              ? FilledButton.icon(
            onPressed: () => context.push(Routes.storeProfileEdit),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.edit_rounded, size: 20),
            label: Text(context.str('storedetails_storeprofile_editProfile')),
          )
              : IconButton(onPressed: () => context.push(Routes.storeProfileEdit), tooltip: context.str('storedetails_storeprofile_editProfile'), icon: Icon(Icons.edit_outlined, color: context.primary)),
      ],
      child: RefreshIndicator(
        color: context.primary,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 8, wide ? 0 : 16, 24),
          children: [body],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.p, required this.isOpen, required this.wide});

  final StoreProfile p;
  final bool isOpen;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    const gap = SizedBox(height: 12);

    Widget card(String? titleKey, List<Widget> rows) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titleKey != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.str(titleKey), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tk.text1))),
            ...rows,
          ],
        ),
      ),
    );

    final header = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Logo(url: p.image, name: p.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tk.text1)),
                  const SizedBox(height: 4),
                  Row(children: [Icon(Icons.verified_rounded, size: 15, color: context.primary), const SizedBox(width: 4), Text(context.str('storedetails_storeprofile_verified_badge'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.primary))]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: isOpen ? tk.success : tk.danger, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(context.str(isOpen ? 'main_storedashboard_store_status_open' : 'main_storedashboard_store_status_closed'), style: TextStyle(fontSize: 12.5, color: tk.text2))),
                  ]),
                  if (p.joined.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${context.str('common_allscreen_joined')}: ${p.joined}', style: TextStyle(fontSize: 12.5, color: tk.text3))),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final contact = card('storedetails_storeprofile_contact_info_title', [
      _ContactRow(icon: Icons.mail_outline_rounded, value: p.email, pillKey: 'common_allscreen_email', onPill: () => launchUrl(Uri(scheme: 'mailto', path: p.email))),
      _ContactRow(icon: Icons.phone_outlined, value: p.phone, pillKey: 'orders_ordersscreen_callLabel', onPill: () => launchUrl(Uri(scheme: 'tel', path: p.phone))),
    ]);

    final address = card('storedetails_storeprofile_address', [
      _InfoRow(icon: Icons.location_on_outlined, value: p.address),
      if (p.landmark.isNotEmpty) _InfoRow(icon: Icons.flag_outlined, label: context.str('storedetails_storeprofile_screen_landMark'), value: p.landmark),
    ]);

    final delivery = card('storedetails_storeprofile_screen_deliveryInformation', [
      if (p.minimumAmountFor.isNotEmpty) _InfoRow(icon: Icons.group_outlined, label: context.str('storedetails_storeprofile_screen_numberOfPersons'), value: p.minimumAmountFor),
      if (p.minimumAmount.isNotEmpty) _InfoRow(icon: Icons.payments_outlined, label: context.str('storedetails_storeprofile_screen_avgMealPrice'), value: money(p.currency, p.minimumAmount)),
      if (p.deliveryTime.isNotEmpty) _InfoRow(icon: Icons.timer_outlined, label: context.str('storedetails_storeprofile_screen_deliveryTime'), value: p.deliveryTime),
    ]);

    final support = (p.supportEmail.isEmpty && p.supportPhone.isEmpty)
        ? null
        : card(null, [
      if (p.supportEmail.isNotEmpty) _ContactRow(icon: Icons.support_agent_rounded, label: context.str('storedetails_storeprofile_supportEmail'), value: p.supportEmail, pillKey: 'common_allscreen_email', onPill: () => launchUrl(Uri(scheme: 'mailto', path: p.supportEmail))),
      if (p.supportPhone.isNotEmpty) _ContactRow(icon: Icons.headset_mic_outlined, label: context.str('storedetails_storeprofile_supportPhone'), value: p.supportPhone, pillKey: 'orders_ordersscreen_callLabel', onPill: () => launchUrl(Uri(scheme: 'tel', path: p.supportPhone))),
    ]);

    final timings = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.schedule_rounded, size: 20, color: context.primary)),
        title: Text(context.str('storedetails_storetimeslots_title'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
        trailing: Icon(Icons.chevron_right_rounded, color: tk.text3),
        onTap: () => context.push(Routes.timings),
      ),
    );

    final slabs = p.availabilityEnabled
        ? Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.event_available_rounded, size: 20, color: context.primary)),
        title: Text(context.str('storedetails_storeprofile_screen_productAvailability'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
        trailing: Icon(Icons.chevron_right_rounded, color: tk.text3),
        onTap: () => context.push(Routes.timeSlabs),
      ),
    )
        : null;

    final left = <Widget>[header, contact, address];
    final right = <Widget>[delivery, ?support, timings, ?slabs];

    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) gap, items[i]]]);

    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: column(left)), const SizedBox(width: 12), Expanded(child: column(right))]);
    }
    return column([...left, ...right]);
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final fallback = Container(
      color: context.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.primary)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        height: 68,
        child: url.isEmpty ? fallback : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 200, placeholder: (_, _) => ColoredBox(color: tk.sunken), errorWidget: (_, _, _) => fallback),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value, this.label});

  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tk.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null) Text(label!, style: TextStyle(fontSize: 12, color: tk.text3)),
              SelectableText(value, style: TextStyle(color: tk.text1, height: 1.35)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// A row with a pill that acts on it (Email opens the mail app, Call opens the dialer).
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value, required this.pillKey, required this.onPill, this.label});

  final IconData icon;
  final String value;
  final String pillKey;
  final VoidCallback onPill;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: tk.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null) Text(label!, style: TextStyle(fontSize: 12, color: tk.text3)),
              Text(value, style: TextStyle(color: tk.text1)),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onPill, style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)), child: Text(context.str(pillKey))),
        ],
      ),
    );
  }
}