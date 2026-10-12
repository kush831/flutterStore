import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_events.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/pos_models.dart';
import '../data/pos_staff_store.dart';
import 'pos_logic.dart';

/// Overridden in main(): the POS token (secure storage, 'pos_' keys) and the staff data.
final posSessionProvider = Provider<SessionStore>((ref) => throw UnimplementedError('posSessionProvider is overridden in main()'));
final posStaffStoreProvider = Provider<PosStaffStore>((ref) => throw UnimplementedError('posStaffStoreProvider is overridden in main()'));

/// POS has its own "session expired" events: a POS token that stops working signs out of POS only, never the store owner.
final posEventsProvider = Provider<SessionEvents>((ref) {
  final e = SessionEvents();
  ref.onDispose(e.dispose);
  return e;
});

/// A second ApiClient that sends the POS token. Every POS data call goes through it.
final posApiProvider = Provider<ApiClient>(
      (ref) => ApiClient(session: ref.watch(posSessionProvider), prefs: ref.watch(appPrefsProvider), events: ref.watch(posEventsProvider)),
);

/// CONVENTION (as userScopeProvider): every provider that holds POS data starts with `ref.watch(posScopeProvider);`.
/// Signing out of POS then clears them all.
class PosScope extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final posScopeProvider = NotifierProvider<PosScope, int>(PosScope.new);

class PosAuthState {
  const PosAuthState({this.staff});

  final PosStaff? staff;

  bool get loggedIn => staff != null;
  List<String> get permissions => staff?.permissions ?? const [];

  bool can(String permission) => permissions.contains(permission);
  bool canAny(Iterable<String> any) => any.any(permissions.contains);
}

class PosAuth extends Notifier<PosAuthState> {
  @override
  PosAuthState build() {
    final sub = ref.read(posEventsProvider).expired.listen((_) => _onExpired());
    ref.onDispose(sub.cancel);
    final session = ref.read(posSessionProvider);
    return PosAuthState(staff: session.isLoggedIn ? ref.read(posStaffStoreProvider).read() : null);
  }

  Future<void> signIn({required String token, required Map<String, dynamic> raw, required PosStaff staff}) async {
    await ref.read(posSessionProvider).saveLogin(token: token); // saveLogin adds "Bearer " itself
    await ref.read(posStaffStoreProvider).save(raw);
    ref.read(posEventsProvider).reset();
    state = PosAuthState(staff: staff);
  }

  Future<void> signOut() async {
    await ref.read(posSessionProvider).clear();
    await ref.read(posStaffStoreProvider).clear();
    ref.read(posEventsProvider).reset();
    ref.read(posScopeProvider.notifier).bump();
    state = const PosAuthState();
  }

  Future<void> _onExpired() async {
    if (!state.loggedIn) {
      ref.read(posEventsProvider).reset();
      return;
    }
    await signOut(); // the router moves to the POS login by itself
  }
}

final posAuthProvider = NotifierProvider<PosAuth, PosAuthState>(PosAuth.new);

/// The currency of the store the staff member belongs to (POS prices use it).
final posCurrencyProvider = Provider<String>((ref) => ref.watch(posAuthProvider.select((s) => s.staff?.business.currency ?? '')));