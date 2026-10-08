import '../../../core/network/json_reader.dart';

class SubCategory {
  const SubCategory({required this.id, required this.name, this.image = ''});

  final String id;
  final String name;
  final String image;

  factory SubCategory.fromJson(JsonReader r) => SubCategory(id: r.text('categoryId'), name: r.text('categoryName'), image: r.text('categoryImage'));
}

class MerchantCategory {
  const MerchantCategory({required this.id, required this.name, this.image = '', this.subs = const []});

  final String id;
  final String name;
  final String image;
  final List<SubCategory> subs;

  /// The search matches the category or any of its sub-categories.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || subs.any((s) => s.name.toLowerCase().contains(q));
  }

  factory MerchantCategory.fromJson(JsonReader r) => MerchantCategory(
    id: r.text('categoryId'),
    name: r.text('categoryName'),
    image: r.text('categoryImage'),
    subs: [for (final s in r.list('subCategories', SubCategory.fromJson)) if (s.name.isNotEmpty) s],
  );
}

// ── options ──────────────────────────────────────────────────────────────────

/// ⚠️ Options use 1 = active and 0 = inactive (products and the store use 1 and 2).
const kOptionActive = 1;
const kOptionInactive = 0;

class OptionType {
  const OptionType(this.id, this.name);

  final int id;
  final String name;

  factory OptionType.fromJson(JsonReader r) => OptionType(r.integer('id') ?? -1, r.text('type'));
}

class OptionItem {
  const OptionItem({required this.id, this.name = '', this.type = '', this.typeId = -1, this.status = kOptionInactive, this.busy = false});

  final int id;
  final String name;
  final String type;
  final int typeId;
  final int status;
  final bool busy; // a switch or delete call is running

  bool get active => status == kOptionActive;

  OptionItem copyWith({int? status, bool? busy}) => OptionItem(id: id, name: name, type: type, typeId: typeId, status: status ?? this.status, busy: busy ?? this.busy);

  factory OptionItem.fromJson(JsonReader r) => OptionItem(
    id: r.integer('id') ?? 0,
    name: r.text('optionName'),
    type: r.text('optionType'),
    typeId: r.integer('optionTypeId') ?? -1,
    status: r.integer('status') ?? kOptionInactive,
  );
}

enum OptionField { name, type }

/// The problems of the option form, all at once: field → key of the server text.
Map<OptionField, String> validateOption({required String name, required int typeId}) => {
  if (name.trim().isEmpty) OptionField.name: 'settings_settings_row_optionNameIsRequired',
  if (typeId < 0) OptionField.type: 'settings_settings_row_pleaseselectAnOptionType',
};

/// The fields of `add-option`. An `id` makes it an update.
Map<String, Object> optionFields({int? id, required String name, required int typeId, required int status, required String locale}) => {
  'name': name.trim(),
  'option_type_id': typeId,
  'status': status,
  if (id != null) 'id': id,
  'locale': locale,
};