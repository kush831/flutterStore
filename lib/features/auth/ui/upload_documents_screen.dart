import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/app_snack.dart';
import '../../../core/design/choice_sheet.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/media/image_picking.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/documents_repository.dart';
import 'auth_split_scaffold.dart';
import 'auth_widgets.dart';

/// signup_status 4: choose a document type, then add the front (and back) photo.
class UploadDocumentsScreen extends ConsumerStatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  ConsumerState<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends ConsumerState<UploadDocumentsScreen> {
  int _selected = 0;
  PickedPhoto? _front;
  PickedPhoto? _back;
  bool _frontMissing = false;
  bool _backMissing = false;
  bool _busy = false;
  String? _banner;

  Future<void> _finish() => ref.read(authControllerProvider.notifier).setSignupStatus(0); // the router moves on

  Future<void> _pick({required bool front}) async {
    final photo = await pickPhoto(context);
    if (photo == null || !mounted) return;
    setState(() {
      if (front) {
        _front = photo;
        _frontMissing = false;
      } else {
        _back = photo;
        _backMissing = false;
      }
    });
  }

  Future<void> _submit(UploadDocType doc) async {
    if (_busy) return;
    // every required side must be present, and a missing one is shown on its slot
    final frontMissing = doc.showFront && _front == null;
    final backMissing = doc.showBack && _back == null;
    setState(() {
      _frontMissing = frontMissing;
      _backMissing = backMissing;
      _banner = null;
    });
    if (frontMissing || backMissing) return;

    setState(() => _busy = true);
    try {
      await ref.read(documentsRepositoryProvider).uploadDocument(
        typeId: doc.id,
        front: doc.showFront ? _front : null,
        back: doc.showBack ? _back : null,
      );
      if (!mounted) return;
      showAppSnack(context, context.str('stripeconnect_stripeconnect_uploadSuccessful'));
      await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = errorText(e, ref.read(stringsProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final async = ref.watch(uploadTypesProvider);

    Widget body;
    if (async.isLoading) {
      body = const SkeletonPulse(
        child: Column(children: [SkeletonBox(height: 56, radius: 12), SizedBox(height: 16), SkeletonBox(height: 150, radius: 14)]),
      );
    } else if (async.hasError) {
      body = Column(
        children: [
          AuthBanner(tone: AuthTone.danger, text: errorText(async.error!, ref.read(stringsProvider))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => ref.invalidate(uploadTypesProvider), child: Text(context.str('common_allscreen_cancel_retry'))),
        ],
      );
    } else {
      final types = async.requireValue;
      if (types.isEmpty) {
        body = Column(
          children: [
            Icon(Icons.verified_rounded, size: 48, color: context.primary),
            const SizedBox(height: 12),
            Text(context.str('stripeconnect_stripeconnect_noDocumentsRequired'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text1)),
            const SizedBox(height: 4),
            Text(context.str('stripeconnect_stripeconnect_youAreAllSet'), style: TextStyle(color: tk.text2)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _finish, child: Text(context.str('common_allscreen_continue'))),
          ],
        );
      } else {
        final doc = types[_selected.clamp(0, types.length - 1)];
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.str('stripeconnect_stripeconnect_uploadClearLegibleImages'), style: TextStyle(fontSize: 13, color: tk.text2, height: 1.4)),
            const SizedBox(height: 16),
            Text(context.str('stripeconnect_stripeconnect_select_type_title'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text1)),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: _busy
                  ? null
                  : () async {
                final id = await showChoiceSheet(
                  context,
                  title: context.str('stripeconnect_stripeconnect_select_type_title'),
                  items: [for (var i = 0; i < types.length; i++) ChoiceItem('$i', types[i].name)],
                  selectedId: '$_selected',
                );
                if (id != null) {
                  setState(() {
                    _selected = int.parse(id);
                    _front = null; // changing the type starts over
                    _back = null;
                    _frontMissing = false;
                    _backMissing = false;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined, size: 20), suffixIcon: Icon(Icons.keyboard_arrow_down_rounded)),
                child: Text(doc.name, style: TextStyle(fontSize: 16, color: tk.text1)),
              ),
            ),
            const SizedBox(height: 18),
            AuthGrid(
              minColumnWidth: 240,
              children: [
                if (doc.showFront)
                  _PhotoSlot(
                    label: context.str('stripeconnect_stripeconnect_front_side_title'),
                    photo: _front,
                    missing: _frontMissing,
                    enabled: !_busy,
                    onTap: () => _pick(front: true),
                    onRemove: () => setState(() => _front = null),
                  ),
                if (doc.showBack)
                  _PhotoSlot(
                    label: context.str('stripeconnect_stripeconnect_back_side_title'),
                    photo: _back,
                    missing: _backMissing,
                    enabled: !_busy,
                    onTap: () => _pick(front: false),
                    onRemove: () => setState(() => _back = null),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (_banner != null) ...[
              AuthBanner(tone: AuthTone.danger, text: _banner!),
              const SizedBox(height: 14),
            ],
            FilledButton(
              onPressed: _busy ? null : () => _submit(doc),
              child: _busy
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(context.str('stripeconnect_stripeconnect_uploading'), overflow: TextOverflow.ellipsis)),
                ],
              )
                  : Text(context.str('stripeconnect_stripeconnect_upload_title')),
            ),
          ],
        );
      }
    }

    return AuthSplitScaffold(
      title: context.str('stripeconnect_stripeconnect_upload_title'),
      subtitle: context.str('stripeconnect_stripeconnect_selectTypeAndUploadImage'),
      brandTitleKey: 'stripeconnect_stripeconnect_upload_title',
      brandSubtitleKey: 'stripeconnect_stripeconnect_veriftyYourIndentiryWithStripe',
      badge: context.str('stripeconnect_stripeconnect_identityVerification'),
      badgeIcon: Icons.verified_user_rounded,
      formMaxWidth: 560,
      onBack: () => ref.read(authControllerProvider.notifier).signOut(),
      child: body,
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label, required this.photo, required this.missing, required this.enabled, required this.onTap, required this.onRemove});

  final String label;
  final PickedPhoto? photo;
  final bool missing;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final primary = context.primary;
    final has = photo != null;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tk.text1)),
        ),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg),
            onTap: enabled ? onTap : null,
            child: Container(
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: missing ? tk.dangerBg : (has ? primary.withValues(alpha: 0.06) : tk.surface),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: missing ? tk.danger : (has ? primary : tk.border), width: has || missing ? 1.6 : 1),
              ),
              child: has
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(photo!.bytes, fit: BoxFit.cover, cacheWidth: (500 * dpr).round()),
                  PositionedDirectional(
                    end: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(50)),
                      child: Text(context.str('common_allscreen_change'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enabled ? onRemove : null,
                        child: const SizedBox(width: 30, height: 30, child: Icon(Icons.close_rounded, color: Colors.white, size: 16)),
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 30, color: missing ? tk.danger : primary),
                  const SizedBox(height: 8),
                  Text(context.str('stripeconnect_stripeconnect_tapToUpload'), style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1)),
                  Text(context.str('stripeconnect_stripeconnect_cameraOrGallery'), style: TextStyle(fontSize: 12, color: tk.text3)),
                ],
              ),
            ),
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.str('common_formvalidation_required_error'), style: TextStyle(color: tk.danger, fontSize: 12)),
          ),
      ],
    );
  }
}