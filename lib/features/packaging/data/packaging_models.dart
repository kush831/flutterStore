import '../../../core/network/json_reader.dart';

class PackagingPref {
  const PackagingPref({required this.id, this.amount = '', this.description = '', this.icon = ''});

  final String id;
  final String amount;
  final String description;
  final String icon;

  factory PackagingPref.fromJson(JsonReader r) => PackagingPref(id: r.text('id'), amount: r.text('amount'), description: r.text('description'), icon: r.text('icon'));
}