import '../../../core/media/image_picking.dart';
import '../data/packaging_models.dart';

enum PackagingField { description, amount }

class PackagingForm {
  const PackagingForm({this.description = '', this.amount = '', this.photo, this.iconUrl = ''});

  final String description;
  final String amount;
  final PickedPhoto? photo; // a new icon
  final String iconUrl; // the icon the server has

  bool get hasIcon => photo != null || iconUrl.isNotEmpty;

  factory PackagingForm.fromPref(PackagingPref p) => PackagingForm(description: p.description, amount: p.amount, iconUrl: p.icon);
}

/// All problems at once: field → key of the server text. Jetpack: both fields are required (here the amount must also be a number).
Map<PackagingField, String> validatePackaging(PackagingForm f) {
  final e = <PackagingField, String>{};
  if (f.description.trim().isEmpty) e[PackagingField.description] = 'settings_settings_section_descriptionRequired';
  final a = f.amount.trim();
  if (a.isEmpty) {
    e[PackagingField.amount] = 'settings_settings_section_amountRequired';
  } else {
    final n = double.tryParse(a);
    if (n == null || n < 0) e[PackagingField.amount] = 'products_addproductscreen_preparation_time_enterValidNumber';
  }
  return e;
}

/// The text fields of the save. The API saves a list, so one item is a list of one: every key ends with [0].
/// An `id` makes it an update.
Map<String, String> packagingFields({String? id, required PackagingForm f}) => {
  'slab_count': '1',
  'description[0]': f.description.trim(),
  'amount[0]': f.amount.trim(),
  if (id != null && id.isNotEmpty) 'package_preference_id[0]': id,
};