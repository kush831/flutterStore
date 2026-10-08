import '../../../core/network/json_reader.dart';

/// A server choice whose key is text: { "key": "1", "value": "Kg" }.
class KeyValue {
  const KeyValue(this.key, this.value);

  final String key;
  final String value;

  factory KeyValue.fromJson(JsonReader r) => KeyValue(r.text('key'), r.text('value'));
}

/// A time window in which the variant is sold at its own price.
class TimeSlab {
  const TimeSlab({required this.id, this.name = '', this.start = '', this.end = '', this.enabled = false, this.price = ''});

  final String id;
  final String name;
  final String start; // HH:mm
  final String end;
  final bool enabled;
  final String price;

  static String _hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  factory TimeSlab.fromJson(JsonReader r) {
    final enabled = r.text('isSelected') == '1';
    final start = _hhmm(r.text('startTime'));
    final end = _hhmm(r.text('endTime'));
    final name = r.text('name');
    return TimeSlab(id: r.text('id'), name: name.isEmpty ? '$start – $end' : name, start: start, end: end, enabled: enabled, price: enabled ? r.text('price') : '');
  }
}

class Variant {
  const Variant({
    required this.id,
    this.sku = '',
    this.title = '',
    this.price = '',
    this.discount = '',
    this.weightUnitId = '',
    this.weight = '',
    this.titleShown = false,
    this.status = '',
    this.slabs = const [],
  });

  final String id;
  final String sku;
  final String title;
  final String price;
  final String discount;
  final String weightUnitId;
  final String weight;
  final bool titleShown; // is_title_show: "1" = shown
  final String status;
  final List<TimeSlab> slabs;

  /// "0", "0.00" and "" mean no discount.
  bool get hasDiscount => !RegExp(r'^[0\s.,]*$').hasMatch(discount);

  factory Variant.fromJson(JsonReader r) => Variant(
    id: r.text('id'),
    sku: r.text('skuId'),
    title: r.text('productTitle'),
    price: r.text('productPrice'),
    discount: r.text('discount'),
    weightUnitId: r.text('weightUnitId'),
    weight: r.text('weight'),
    titleShown: r.text('isTitleShow') == '1',
    status: r.text('status'),
    slabs: [for (final s in r.list('productAvailabilityTimeSlabs', TimeSlab.fromJson)) if (s.id.isNotEmpty) s],
  );
}

class VariantsData {
  const VariantsData({this.variants = const [], this.weightUnits = const [], this.statuses = const [], this.skuId = '', this.skuAutoGenerate = false});

  final List<Variant> variants;
  final List<KeyValue> weightUnits;
  final List<KeyValue> statuses;
  final String skuId;
  final bool skuAutoGenerate;

  String unitName(String id) {
    for (final u in weightUnits) {
      if (u.key == id) return u.value;
    }
    return '';
  }

  String statusName(String key) {
    for (final s in statuses) {
      if (s.key == key) return s.value;
    }
    return '';
  }

  factory VariantsData.fromJson(JsonReader root) {
    final d = root.sub('data');
    return VariantsData(
      variants: [for (final v in d.list('productVariants', Variant.fromJson)) if (v.id.isNotEmpty) v],
      weightUnits: d.list('arrWeightUnit', KeyValue.fromJson),
      statuses: d.list('productStatus', KeyValue.fromJson),
      skuId: d.text('skuId'),
      skuAutoGenerate: d.flag('enableSkuAutoGenerate'),
    );
  }
}

/// One variant on the stock tab.
class StockVariant {
  const StockVariant({required this.id, this.title = '', this.sku = '', this.weight = '', this.unitId = '', this.currentStock = '', this.cost = '', this.selling = ''});

  final String id;
  final String title;
  final String sku;
  final String weight;
  final String unitId;
  final String currentStock;
  final String cost;
  final String selling;

  int get stock => int.tryParse(currentStock.trim()) ?? 0;

  factory StockVariant.fromJson(JsonReader r) {
    final inv = r.sub('productInventory');
    return StockVariant(
      id: r.text('id'),
      title: r.text('productTitle'),
      sku: r.text('skuId'),
      weight: r.text('weight'),
      unitId: r.text('weightUnitId'),
      currentStock: inv.text('currentStock'),
      cost: inv.text('productCost'),
      selling: inv.text('productSellingPrice'),
    );
  }
}

class StockData {
  const StockData(this.variants);

  final List<StockVariant> variants;

  factory StockData.fromJson(JsonReader root) => StockData([for (final v in root.sub('data').list('productVariants', StockVariant.fromJson)) if (v.id.isNotEmpty) v]);
}