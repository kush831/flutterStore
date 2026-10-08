import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import 'catalog_models.dart';

class CatalogRepository {
  CatalogRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  String get _locale => _prefs.language ?? 'en';

  Future<List<MerchantCategory>> categoryTree() async {
    final root = await _api.get(EndPoints.merchantCategories);
    return [for (final c in root.sub('data').list('categories', MerchantCategory.fromJson)) if (c.name.isNotEmpty) c];
  }

  Future<PageResult<OptionItem>> optionsPage(int page) async {
    final root = await _api.postForm(EndPoints.getOptions, {'page': page});
    final d = root.sub('data');
    final items = [for (final o in d.list('responseData', OptionItem.fromJson)) if (o.id != 0) o];
    return PageResult(items, nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty));
  }

  Future<List<OptionType>> optionTypes() async {
    final root = await _api.postForm(EndPoints.optionTypes);
    return [for (final t in root.sub('data').list('responseData', OptionType.fromJson)) if (t.id >= 0) t];
  }

  /// Creates an option, or updates it when `id` is given. Returns the server's message.
  Future<String> saveOption({int? id, required String name, required int typeId, required int status}) async {
    final root = await _api.postForm(EndPoints.saveOption, optionFields(id: id, name: name, typeId: typeId, status: status, locale: _locale));
    return root.text('message');
  }

  Future<String> deleteOption(int id) async {
    final root = await _api.postForm(EndPoints.deleteOption, {'option_id': id, 'locale': _locale});
    return root.text('message');
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
      (ref) => CatalogRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);