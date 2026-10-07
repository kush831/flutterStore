import '../../../core/network/json_reader.dart';

class Driver {
  const Driver({required this.id, required this.name, this.rating = '', this.distance = '', this.image = ''});

  final int id;
  final String name;
  final String rating;
  final String distance; // already formatted by the server ("1.2 km")
  final String image;

  factory Driver.fromJson(JsonReader r) => Driver(
    id: r.integer('id') ?? 0,
    name: r.text('name'),
    rating: r.text('rating'),
    distance: r.text('distance'),
    image: r.text('profileImage'),
  );
}