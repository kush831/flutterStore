import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/error_text.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

@immutable
class DashboardState {
  const DashboardState({
    this.home = const AsyncValue<DashboardData>.loading(),
    this.summary = const AsyncValue<BusinessSummary>.loading(),
    this.openOverride,
    this.updating = false,
    this.popupShown = false,
  });

  final AsyncValue<DashboardData> home;
  final AsyncValue<BusinessSummary> summary;

  /// The switch position while the server call is running (optimistic).
  final bool? openOverride;
  final bool updating;
  final bool popupShown;

  /// null until the dashboard has loaded.
  bool? get isOpen => openOverride ?? home.value?.isOpen;

  DashboardState copyWith({
    AsyncValue<DashboardData>? home,
    AsyncValue<BusinessSummary>? summary,
    bool? openOverride,
    bool clearOverride = false,
    bool? updating,
    bool? popupShown,
  }) =>
      DashboardState(
        home: home ?? this.home,
        summary: summary ?? this.summary,
        openOverride: clearOverride ? null : (openOverride ?? this.openOverride),
        updating: updating ?? this.updating,
        popupShown: popupShown ?? this.popupShown,
      );
}

/// Lives as long as the signed-in session (the app frame reads it too).
class DashboardController extends Notifier<DashboardState> {
  int _generation = 0;

  DashboardRepository get _repo => ref.read(dashboardRepositoryProvider);

  @override
  DashboardState build() {
    ref.watch(userScopeProvider); // a sign-out throws the previous store's data away
    Future.microtask(refresh);
    return const DashboardState();
  }

  /// Loads both APIs in parallel. Existing data stays on screen while it refreshes,
  /// and one failing API never blanks the other card.
  Future<void> refresh() async {
    final gen = ++_generation;

    Future<void> loadHome() async {
      try {
        final d = await _repo.home();
        if (gen != _generation) return;
        state = state.copyWith(home: AsyncValue.data(d));
        if (d.currency.isNotEmpty) await ref.read(appPrefsProvider).setCurrency(d.currency);
      } catch (e, st) {
        if (gen != _generation || (e is AppException && e.isSession)) return;
        if (!state.home.hasValue) state = state.copyWith(home: AsyncValue.error(e, st));
      }
    }

    Future<void> loadSummary() async {
      try {
        final s = await _repo.summary();
        if (gen != _generation) return;
        state = state.copyWith(summary: AsyncValue.data(s));
      } catch (e, st) {
        if (gen != _generation || (e is AppException && e.isSession)) return;
        if (!state.summary.hasValue) state = state.copyWith(summary: AsyncValue.error(e, st));
      }
    }

    // a retry shows the skeleton again only where nothing is on screen yet
    if (!state.home.hasValue && state.home.hasError) state = state.copyWith(home: const AsyncValue.loading());
    if (!state.summary.hasValue && state.summary.hasError) state = state.copyWith(summary: const AsyncValue.loading());

    await Future.wait([loadHome(), loadSummary()]);
  }

  /// Returns an error text, or null on success. The switch moves at once and goes back if the server refuses.
  Future<String?> toggleOpen(bool open) async {
    if (state.updating) return null;
    state = state.copyWith(openOverride: open, updating: true);
    try {
      await _repo.setStoreOpen(open);
      applyRemoteStoreStatus(open);
      state = state.copyWith(clearOverride: true, updating: false);
      return null;
    } catch (e) {
      state = state.copyWith(clearOverride: true, updating: false);
      return errorText(e, ref.read(stringsProvider));
    }
  }

  /// Also used when a push notification says the store was opened / closed elsewhere (Step 24).
  void applyRemoteStoreStatus(bool open) {
    final h = state.home.value;
    if (h != null) state = state.copyWith(home: AsyncValue.data(h.copyWith(isOpen: open)));
  }

  void markPopupShown() => state = state.copyWith(popupShown: true);
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(DashboardController.new);