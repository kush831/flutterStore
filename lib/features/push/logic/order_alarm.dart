import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one sound of the app: the same code on Android, iPhone and browser.
const kOrderSoundAsset = 'sounds/new_order.wav';

class OrderAlarm {
  AudioPlayer? _player;
  String? _activeId;

  /// Loops until [stop] (accepting, opening or closing the banner).
  Future<void> start(String orderId) async {
    try {
      _activeId = orderId;
      _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource(kOrderSoundAsset));
    } catch (_) {} // a browser may block sound until the page was clicked once
  }

  /// Once.
  Future<void> ring() async {
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(AssetSource(kOrderSoundAsset));
    } catch (_) {}
  }

  /// With an order id only that order's alarm stops; without one any alarm stops.
  Future<void> stop([String? orderId]) async {
    if (orderId != null && orderId.isNotEmpty && orderId != _activeId) return;
    try {
      await _player?.stop();
    } catch (_) {}
    _activeId = null;
  }

  Future<void> setNonStop(bool on) async {} // kept so the callers do not change
}

final orderAlarmProvider = Provider<OrderAlarm>((ref) => OrderAlarm());