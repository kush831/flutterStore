import 'dart:io' show InternetAddressType, NetworkInterface;

import 'package:flutter/foundation.dart';

/// The first non-loopback IPv4 address of this device, or 0.0.0.0.
/// ⚠️ This is the LOCAL network address (what Jetpack sent). Stripe wants the public IP, which only the
/// server can see in the request: please ask the backend team to use the request IP and ignore this field.
Future<String> deviceIp() async {
  if (kIsWeb) return '0.0.0.0';
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (!a.isLoopback) return a.address;
      }
    }
  } catch (_) {}
  return '0.0.0.0';
}