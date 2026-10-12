import 'dart:convert';

import '../../../core/network/json_reader.dart';

class CuisineStyle {
  const CuisineStyle({required this.id, this.name = '', this.checked = false});

  final String id;
  final String name;
  final bool checked; // the store has it now

  factory CuisineStyle.fromJson(JsonReader r) => CuisineStyle(id: r.text('id'), name: r.text('name'), checked: r.flag('checked'));
}

/// The chosen ids after a tap: added when missing, removed when there.
Set<String> toggleStyle(Set<String> chosen, String id) => chosen.contains(id) ? ({...chosen}..remove(id)) : {...chosen, id};

/// What the server wants in `arr_style`: a JSON text, `[{"id":"1"},{"id":"2"}]`. The order follows the list the server sent.
String stylesPayload(List<CuisineStyle> all, Set<String> chosen) => jsonEncode([for (final s in all) if (chosen.contains(s.id)) {'id': s.id}]);