import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_snack.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/design/sub_page.dart';
import '../../../core/media/image_picking.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../home/logic/dashboard_controller.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../logic/store_logic.dart';
import '../logic/store_providers.dart';

class StoreEditScreen extends ConsumerStatefulWidget {
  const StoreEditScreen({super.key});

  @override
  ConsumerState<StoreEditScreen> createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends ConsumerState<StoreEditScreen> {
  final _c = {for (final f in StoreField.values) f: TextEditingController()};
  final _keys = {for (final f in StoreField.values) f: GlobalKey()};

  PickedPhoto? _photo;
  String _logoUrl = '';
  bool _packaging = false;
  bool _availability = false;
  bool _initialized = false;
  Map<StoreField, String> _errors = {};
  bool _saving = false;
  double _progress = 0;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _init(StoreProfile p) {
    _c[StoreField.name]!.text = p.name;
    _c[StoreField.email]!.text = p.email;
    _c[StoreField.phone]!.text = p.phone;
    _c[StoreField.address]!.text = p.address;
    _c[StoreField.landmark]!.text = p.landmark;
    _c[StoreField.latitude]!.text = p.latitude;
    _c[StoreField.longitude]!.text = p.longitude;
    _c[StoreField.persons]!.text = p.minimumAmountFor;
    _c[StoreField.avgPrice]!.text = p.minimumAmount;
    _c[StoreField.deliveryTime]!.text = p.deliveryTime;
    _logoUrl = p.image;
    _packaging = p.packagingEnabled;
    _availability = p.availabilityEnabled;
    _initialized = true;
  }

  StoreForm _collect() => StoreForm(
    photo: _photo,
    name: _c[StoreField.name]!.text,
    email: _c[StoreField.email]!.text,
    phone: _c[StoreField.phone]!.text,
    address: _c[StoreField.address]!.text,
    landmark: _c[StoreField.landmark]!.text,
    latitude: _c[StoreField.latitude]!.text,
    longitude: _c[StoreField.longitude]!.text,
    persons: _c[StoreField.persons]!.text,
    avgPrice: _c[StoreField.avgPrice]!.text,
    deliveryTime: _c[StoreField.deliveryTime]!.text,
    packaging: _packaging,
    availability: _availability,
  );

  void _clear(StoreField f) {
    if (_errors.containsKey(f)) setState(() => _errors = {..._errors}..remove(f));
  }

  Future<void> _pickLogo() async {
    final photo = await pickPhoto(context);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  void _scrollToFirstError(Map<StoreField, String> errors) {
    for (final f in StoreField.values) {
      if (!errors.containsKey(f)) continue;
      final ctx = _keys[f]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      return;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final f = _collect();
    final errors = validateStore(f);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstError(errors));
      return;
    }
    setState(() {
      _saving = true;
      _progress = 0;
    });
    try {
      final message = await ref.read(storeRepositoryProvider).saveProfile(f, onProgress: (v) {
        if (mounted) setState(() => _progress = v);
      });
      if (!mounted) return;
      ref.invalidate(storeProfileProvider);
      ref.read(dashboardProvider.notifier).refresh(); // the store name on Home
      if (message.isNotEmpty) showAppSnack(context, message);
      context.canPop() ? context.pop() : context.go(Routes.storeProfile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, errorText(e, ref.read(stringsProvider)), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final compact = context.screen.isCompact;
    final async = ref.watch(storeProfileProvider);
    final p = async.value;
    if (p != null && !_initialized && !async.isLoading) _init(p);
    final ready = p != null && _initialized;

    final saveButton = FilledButton(
      onPressed: (ready && !_saving) ? _save : null,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      child: _saving
          ? Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 10), Text(context.str('common_allscreen_saving'))])
          : Text(context.str('storedetails_storeprofile_save_changes_button')),
    );

    final Widget content;
    if (ready) {
      content = _form();
    } else if (async.hasError && p == null) {
      content = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: tk.text3),
          const SizedBox(height: 10),
          Text(errorText(async.error!, ref.read(stringsProvider)), textAlign: TextAlign.center, style: TextStyle(color: tk.text2)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: () => ref.invalidate(storeProfileProvider), child: Text(context.str('common_allscreen_try_again'))),
        ]),
      );
    } else {
      content = const SkeletonPulse(child: Column(children: [SkeletonBox(height: 110, radius: 16), SizedBox(height: 12), SkeletonBox(height: 56, radius: 12), SizedBox(height: 12), SkeletonBox(height: 56, radius: 12)]));
    }

    return SubPage(
      title: context.str('storedetails_storeprofile_editProfile'),
      fallbackRoute: Routes.storeProfile,
      actions: [if (!compact) saveButton],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _saving ? LinearProgressIndicator(value: _progress > 0 && _progress < 1 ? _progress : null, minHeight: 3) : const SizedBox(height: 3),
          Expanded(child: ListView(padding: EdgeInsets.fromLTRB(compact ? 16 : 0, 12, compact ? 16 : 0, 24), children: [content])),
          if (compact)
            Container(
              decoration: BoxDecoration(color: tk.surface, border: Border(top: BorderSide(color: tk.border))),
              child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: SizedBox(width: double.infinity, child: saveButton))),
            ),
        ],
      ),
    );
  }

  Widget _form() {
    final tk = context.tk;
    String? err(StoreField f) => _errors[f] == null ? null : context.str(_errors[f]!);

    Widget field(StoreField f, String labelKey, {String? hintKey, TextInputType? type, List<TextInputFormatter>? formatters, int minLines = 1, int maxLines = 1, TextCapitalization caps = TextCapitalization.none}) => Column(
      key: _keys[f],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.str(labelKey), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text2))),
        TextField(
          controller: _c[f],
          enabled: !_saving,
          keyboardType: type,
          inputFormatters: formatters,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: caps,
          onChanged: (_) => _clear(f),
          decoration: InputDecoration(hintText: hintKey == null ? null : context.str(hintKey), errorText: err(f)),
        ),
      ],
    );

    Widget section(String titleKey, List<(Widget, bool)> cells) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(context.str(titleKey), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tk.text1))),
        _Grid(cells: cells),
        const SizedBox(height: 14),
      ],
    );

    Widget switchTile(String titleKey, String subtitleKey, bool value, ValueChanged<bool> onChanged) => Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: tk.border)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str(titleKey), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
            Text(context.str(subtitleKey), style: TextStyle(fontSize: 12.5, color: tk.text2)),
          ]),
        ),
        Switch(value: value, onChanged: _saving ? null : onChanged),
      ]),
    );

    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimals = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final signed = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))];

    final logo = Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _saving ? null : _pickLogo,
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 84,
                height: 84,
                child: _photo != null
                    ? Image.memory(_photo!.bytes, fit: BoxFit.cover)
                    : (_logoUrl.isEmpty ? ColoredBox(color: tk.sunken, child: Icon(Icons.storefront_rounded, size: 34, color: tk.text3)) : CachedNetworkImage(imageUrl: _logoUrl, fit: BoxFit.cover, memCacheWidth: 260, errorWidget: (_, _, _) => ColoredBox(color: tk.sunken))),
              ),
            ),
            PositionedDirectional(end: 4, bottom: 4, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white))),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.str('storedetails_storeprofile_storeLogo'), style: TextStyle(fontWeight: FontWeight.w700, color: tk.text1)),
            Text(context.str('storedetails_storeprofile_pngOrJpgRecommended'), style: TextStyle(fontSize: 12.5, color: tk.text3)),
            const SizedBox(height: 6),
            TextButton(onPressed: _saving ? null : _pickLogo, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: AlignmentDirectional.centerStart), child: Text(context.str('storedetails_storeprofile_change_logo_button'))),
          ]),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        logo,
        const SizedBox(height: 14),
        section('storedetails_storeprofile_basic_information_title', [
          (field(StoreField.name, 'storedetails_storeprofile_store_name_title', hintKey: 'storedetails_storeprofile_store_name_placeholder', caps: TextCapitalization.words), false),
          (field(StoreField.phone, 'storedetails_storeprofile_phone_number_title', hintKey: 'storedetails_storeprofile_phone_placeholder', type: TextInputType.phone, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))]), false),
          (field(StoreField.email, 'storedetails_storeprofile_email', hintKey: 'storedetails_storeprofile_email_placeholder', type: TextInputType.emailAddress), true),
        ]),
        section('storedetails_storeprofile_address', [
          (field(StoreField.address, 'storedetails_storeprofile_address', hintKey: 'storedetails_storeprofile_street_placeholder', minLines: 2, maxLines: 4, caps: TextCapitalization.sentences), true),
          (field(StoreField.landmark, 'storedetails_storeprofile_screen_landMark', caps: TextCapitalization.sentences), true),
          (field(StoreField.latitude, 'storedetails_storeprofile_screen_latitude', hintKey: 'storedetails_storeprofile_screen_latitudePlaceHolder', type: const TextInputType.numberWithOptions(decimal: true, signed: true), formatters: signed), false),
          (field(StoreField.longitude, 'storedetails_storeprofile_screen_longitude', hintKey: 'storedetails_storeprofile_screen_longitudePlaceHolder', type: const TextInputType.numberWithOptions(decimal: true, signed: true), formatters: signed), false),
        ]),
        section('storedetails_storeprofile_screen_deliveryInformation', [
          (field(StoreField.persons, 'storedetails_storeprofile_screen_numberOfPersons', hintKey: 'storedetails_storeprofile_screen_numberOfPersonsPlaceHolder', type: TextInputType.number, formatters: digits), false),
          (field(StoreField.avgPrice, 'storedetails_storeprofile_screen_avgMealPrice', hintKey: 'storedetails_storeprofile_screen_avgMealPricePlaceHolder', type: const TextInputType.numberWithOptions(decimal: true), formatters: decimals), false),
          (field(StoreField.deliveryTime, 'storedetails_storeprofile_screen_deliveryTime', hintKey: 'storedetails_storeprofile_screen_selectDeliveryTime'), true),
        ]),
        section('storedetails_storeprofile_screen_otherServices', [
          (switchTile('storedetails_storeprofile_screen_enableCustomPackagingOptions', 'storedetails_storeprofile_screen_enableCustomPackagingOptions', _packaging, (v) => setState(() => _packaging = v)), true),
          (switchTile('storedetails_storeprofile_screen_productAvailability', 'storedetails_storeprofile_screen_setTimeSlabsForAvailability', _availability, (v) => setState(() => _availability = v)), true),
          if (_availability)
            (
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => context.push(Routes.timeSlabs),
                icon: const Icon(Icons.schedule_rounded, size: 20),
                label: Text(context.str('storedetails_storeprofile_productAvailableTimeSlabs')),
              ),
            ),
            true,
            ),
        ]),
      ],
    );
  }
}

/// Two columns on wide forms; `true` = the cell takes the full width.
class _Grid extends StatelessWidget {
  const _Grid({required this.cells});

  final List<(Widget, bool)> cells;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    const gap = 16.0;
    final two = box.maxWidth >= 640;
    final half = (box.maxWidth - gap) / 2;
    return Wrap(spacing: gap, runSpacing: 16, children: [for (final (w, full) in cells) SizedBox(width: (two && !full) ? half : box.maxWidth, child: w)]);
  });
}