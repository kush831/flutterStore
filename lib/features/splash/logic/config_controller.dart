import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/app_config.dart';
import '../data/config_repository.dart';

@immutable
class ConfigState {
  const ConfigState({this.config, this.fromCache = false, this.loading = false, this.error});

  final AppConfig? config;
  final bool fromCache;
  final bool loading;
  final String? error;
}

class ConfigController extends Notifier<ConfigState> {
  Future<AppConfig?>? _inflight;

  ConfigRepository get _repo => ref.read(configRepositoryProvider);

  @override
  ConfigState build() {
    final cached = _repo.readCache();
    return ConfigState(config: cached, fromCache: cached != null);
  }

  /// For the splash: the best configuration available in time.
  ///  • saved copy exists → wait up to 2 s for a fresh one (a maintenance flag may have changed)
  ///  • nothing saved     → wait up to 8 s
  /// The download keeps running in the background after the timeout.
  Future<AppConfig?> loadForStartup() async {
    final hadCache = state.config != null;
    final wait = Duration(seconds: hadCache ? 2 : 8);
    try {
      final fresh = await refresh().timeout(wait);
      return fresh ?? state.config;
    } on TimeoutException {
      return state.config;
    }
  }

  /// Downloads a fresh copy. Never throws: returns null on failure (the old copy stays).
  Future<AppConfig?> refresh() => _inflight ??= _download().whenComplete(() => _inflight = null);

  Future<AppConfig?> _download() async {
    state = ConfigState(config: state.config, fromCache: state.fromCache, loading: true);
    try {
      final cfg = await _repo.fetch();
      state = ConfigState(config: cfg);
      return cfg;
    } catch (e) {
      debugPrint('Configuration download failed: $e');
      state = ConfigState(config: state.config, fromCache: state.config != null, error: AppException.messageOf(e));
      return null;
    }
  }
}

final configProvider = NotifierProvider<ConfigController, ConfigState>(ConfigController.new);

/// Shortcut for screens: the current configuration, or null.
final appConfigProvider = Provider<AppConfig?>((ref) => ref.watch(configProvider.select((s) => s.config)));