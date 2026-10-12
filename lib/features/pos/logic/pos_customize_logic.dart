import '../data/pos_catalog_models.dart';

enum CustomizeStep { size, extras, review }

/// Jetpack's wizard: Size only when there are several variants, Extras only when there are modifier groups, Review always.
List<CustomizeStep> stepsFor(PosProduct p) => [if (p.variants.length > 1) CustomizeStep.size, if (p.modifiers.isNotEmpty) CustomizeStep.extras, CustomizeStep.review];

/// A tap on an extra: picks it, or drops it when it was picked. At the group's maximum nothing more can be picked.
Set<String> toggleModifier(PosModifierGroup group, Set<String> chosen, PosModifierContent content) {
  if (chosen.contains(content.id)) return {...chosen}..remove(content.id);
  if (chosen.length >= group.limit) return chosen;
  return {...chosen, content.id};
}

/// Every mandatory group has at least one pick.
bool extrasComplete(List<PosModifierGroup> groups, Map<int, Set<String>> chosen) {
  for (var i = 0; i < groups.length; i++) {
    if (groups[i].mandatory && (chosen[i] ?? const <String>{}).isEmpty) return false;
  }
  return true;
}

/// The picked extras, in the order of the groups.
List<PosModifierContent> chosenModifiers(List<PosModifierGroup> groups, Map<int, Set<String>> chosen) => [
  for (var i = 0; i < groups.length; i++)
    for (final c in groups[i].contents)
      if ((chosen[i] ?? const <String>{}).contains(c.id)) c,
];

/// The price of one item: the variant plus its extras.
double customizeUnit(PosVariant v, List<PosModifierContent> mods) => v.unit + mods.fold(0.0, (a, m) => a + m.amount);

/// What the customer saves on [qty] items through the variant's discount.
double customizeSavings(PosVariant v, int qty) => v.hasDiscount ? (v.base - v.unit) * qty : 0;