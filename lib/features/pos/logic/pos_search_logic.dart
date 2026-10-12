import '../data/pos_catalog_models.dart';
import 'pos_shift_logic.dart' show posNum;

/// Jetpack searches from 2 characters on.
bool searchReady(String q) => q.trim().length >= 2;

/// A scanned code as the search box gets it: no stray spaces or line breaks.
String normalizeScan(String raw) => raw.trim();

/// The range a product can cost, from the product detail: the cheapest variant on its own, up to the dearest variant with the
/// dearest option of every option group. null when there are no variants to price.
({double min, double max})? priceRange(List<PosDetailVariant> variants, List<PosOptionGroup> options) {
  final prices = [for (final v in variants) posNum(v.price)];
  if (prices.isEmpty) return null;
  var min = prices.first;
  var max = prices.first;
  for (final p in prices) {
    if (p < min) min = p;
    if (p > max) max = p;
  }
  final extras = options.fold(0.0, (a, g) => a + g.items.fold(0.0, (m, o) => posNum(o.amount) > m ? posNum(o.amount) : m));
  return (min: min, max: max + extras);
}