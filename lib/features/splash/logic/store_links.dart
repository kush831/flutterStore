import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_config.dart';

/// Opens this app's page in Google Play / the App Store.
Future<void> openStoreListing(UpdateInfo update) async {
  try {
    final info = await PackageInfo.fromPlatform();
    Uri? uri;
    Uri? fallback;
    if (defaultTargetPlatform == TargetPlatform.android) {
      uri = Uri.parse('market://details?id=${info.packageName}');
      fallback = Uri.parse('https://play.google.com/store/apps/details?id=${info.packageName}');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (update.iosStoreLink.isNotEmpty) {
        uri = Uri.parse(update.iosStoreLink);
      } else if (update.iosStoreAppId.isNotEmpty) {
        uri = Uri.parse('https://apps.apple.com/app/id${update.iosStoreAppId}');
      }
    }
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && fallback != null) await launchUrl(fallback, mode: LaunchMode.externalApplication);
  } catch (_) {
    // no store app installed: nothing to do
  }
}