import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/error_text.dart';
import '../../../core/network/paging.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

final categoryTreeProvider = FutureProvider.autoDispose<List<MerchantCategory>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(catalogRepositoryProvider).categoryTree();
});

final optionTypesProvider = FutureProvider.autoDispose<List<OptionType>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(catalogRepositoryProvider).optionTypes();
});

class OptionsController extends PagedNotifier<OptionItem> {
  CatalogRepository get _repo => ref.read(catalogRepositoryProvider);

  @override
  PagedState<OptionItem> build() {
    ref.watch(userScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<OptionItem>> fetchPage(int page) => _repo.optionsPage(page);

  void _patch(int id, OptionItem Function(OptionItem) update) {
    if (!ref.mounted) return;
    updateWhere((o) => o.id == id, update);
  }

  /// The switch moves at once. Returns the error text (and puts the switch back) when the server refuses.
  /// ⚠️ Sends the NEW status (Jetpack's row switch sent the old one).
  Future<String?> setActive(OptionItem o, bool on) async {
    final before = o.status;
    final next = on ? kOptionActive : kOptionInactive;
    _patch(o.id, (x) => x.copyWith(status: next, busy: true));
    try {
      await _repo.saveOption(id: o.id, name: o.name, typeId: o.typeId, status: next);
      _patch(o.id, (x) => x.copyWith(busy: false));
      return null;
    } catch (e) {
      _patch(o.id, (x) => x.copyWith(status: before, busy: false));
      return errorText(e, ref.read(stringsProvider));
    }
  }

  /// Removes the option from the list once the server confirms. Returns the error text on a refusal.
  Future<String?> remove(OptionItem o) async {
    _patch(o.id, (x) => x.copyWith(busy: true));
    try {
      await _repo.deleteOption(o.id);
      if (ref.mounted) removeWhere((x) => x.id == o.id);
      return null;
    } catch (e) {
      _patch(o.id, (x) => x.copyWith(busy: false));
      return errorText(e, ref.read(stringsProvider));
    }
  }
}

final optionsProvider = NotifierProvider.autoDispose<OptionsController, PagedState<OptionItem>>(OptionsController.new);