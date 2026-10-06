import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../design/design_tokens.dart';
import '../strings/strings_scope.dart';

/// A photo held in memory only (never written to storage).
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Camera / Gallery sheet, then the photo scaled to at most 1600 px at 85% quality
/// (sharp enough to read a document, small enough to upload quickly).
/// The camera permission is requested by the system only when the camera is chosen.
Future<PickedPhoto?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ctx.str('stripeconnect_stripeconnect_selectImage'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.tk.text1)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _SourceTile(icon: Icons.photo_camera_outlined, label: ctx.str('stripeconnect_stripeconnect_camera'), onTap: () => Navigator.pop(ctx, ImageSource.camera))),
                const SizedBox(width: 12),
                Expanded(child: _SourceTile(icon: Icons.photo_library_outlined, label: ctx.str('stripeconnect_stripeconnect_gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;

  try {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), name: file.name.isEmpty ? 'photo.jpg' : file.name);
  } catch (_) {
    // permission denied or no camera
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.str('common_allscreen_something_went_wrong'))));
    }
    return null;
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: context.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Icon(icon, size: 30, color: context.primary),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: tk.text1)),
            ],
          ),
        ),
      ),
    );
  }
}