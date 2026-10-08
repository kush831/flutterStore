import '../data/variant_models.dart';

enum VariantField { title, price, discount, weight }

class SlabState {
  const SlabState({required this.id, this.name = '', this.start = '', this.end = '', this.enabled = false, this.price = ''});

  final String id;
  final String name;
  final String start;
  final String end;
  final bool enabled;
  final String price;

  SlabState copyWith({bool? enabled, String? price}) =>
      SlabState(id: id, name: name, start: start, end: end, enabled: enabled ?? this.enabled, price: price ?? this.price);

  factory SlabState.fromSlab(TimeSlab s) => SlabState(id: s.id, name: s.name, start: s.start, end: s.end, enabled: s.enabled, price: s.price);
}

class VariantForm {
  const VariantForm({
    this.sku = '',
    this.title = '',
    this.statusKey = '1',
    this.price = '',
    this.discount = '',
    this.weightUnitId = '',
    this.weight = '',
    this.titleShown = false,
    this.slabs = const [],
  });

  final String sku;
  final String title;
  final String statusKey; // "1" = available (Jetpack's default)
  final String price;
  final String discount;
  final String weightUnitId;
  final String weight;
  final bool titleShown;
  final List<SlabState> slabs;

  VariantForm copyWith({
    String? sku,
    String? title,
    String? statusKey,
    String? price,
    String? discount,
    String? weightUnitId,
    String? weight,
    bool? titleShown,
    List<SlabState>? slabs,
  }) =>
      VariantForm(
        sku: sku ?? this.sku,
        title: title ?? this.title,
        statusKey: statusKey ?? this.statusKey,
        price: price ?? this.price,
        discount: discount ?? this.discount,
        weightUnitId: weightUnitId ?? this.weightUnitId,
        weight: weight ?? this.weight,
        titleShown: titleShown ?? this.titleShown,
        slabs: slabs ?? this.slabs,
      );

  factory VariantForm.fromVariant(Variant v) => VariantForm(
    sku: v.sku,
    title: v.title,
    statusKey: v.status.isEmpty ? '1' : v.status,
    price: v.price,
    discount: v.hasDiscount ? v.discount : '',
    weightUnitId: v.weightUnitId,
    weight: v.weight,
    titleShown: v.titleShown,
    slabs: [for (final s in v.slabs) SlabState.fromSlab(s)],
  );
}

bool _isNumber(String s) {
  final n = double.tryParse(s.trim());
  return n != null && n >= 0;
}

/// The problems of a variant, all at once: field → key of the server text to show.
Map<VariantField, String> validateVariant(VariantForm f) {
  const required = 'common_formvalidation_required_error';
  const invalid = 'products_addproductscreen_preparation_time_enterValidNumber'; // "Enter a valid number"
  final e = <VariantField, String>{};
  if (f.title.trim().isEmpty) e[VariantField.title] = required;
  if (f.price.trim().isEmpty) {
    e[VariantField.price] = required;
  } else if (!_isNumber(f.price)) {
    e[VariantField.price] = invalid;
  }
  if (f.discount.trim().isNotEmpty) {
    final n = double.tryParse(f.discount.trim());
    if (n == null || n < 0 || n > 100) e[VariantField.discount] = invalid; // a percentage
  }
  if (f.weight.trim().isNotEmpty && !_isNumber(f.weight)) e[VariantField.weight] = invalid;
  return e;
}

/// The body of `save-product-step2`. ⚠️ is_title_show is "on" / "off" (not 1 / 0), and the slabs are three parallel lists.
/// A slab that is switched off is sent with price "0" (Jetpack).
Map<String, Object> variantBody({required String productId, required String variantId, required VariantForm f, required String locale}) => {
  'sku_id': f.sku.trim(),
  'title': f.title.trim(),
  'status': f.statusKey,
  'price': f.price.trim(),
  'discount': f.discount.trim(),
  'weight_unit_id': f.weightUnitId,
  'weight': f.weight.trim(),
  'product_id': productId,
  'product_variant_id': variantId, // '' for a new variant
  'is_title_show': f.titleShown ? 'on' : 'off',
  'locale': locale,
  'time_slab_ids': [for (final s in f.slabs) s.id],
  'time_slab_enable': [for (final s in f.slabs) s.enabled ? 1 : 0],
  'time_slab_price': [for (final s in f.slabs) s.enabled ? (s.price.trim().isEmpty ? '0' : s.price.trim()) : '0'],
};

/// The stock after an adjustment. The server wants the NEW TOTAL, not the change.
int stockAfter(int current, int change) => current + change;

/// You cannot take out more than there is.
bool canDecrease(int current, int change) => current + change - 1 >= 0;