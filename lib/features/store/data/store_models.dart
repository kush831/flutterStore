import '../../../core/network/json_reader.dart';
import '../logic/store_logic.dart';

/// One day of the week: open or closed, and from/to what time ("HH:mm").
class DaySchedule {
  const DaySchedule({required this.id, required this.name, this.open = kDefaultOpen, this.close = kDefaultClose, this.enabled = false});

  final int id;
  final String name; // as the server sends it (already in the user's language)
  final String open;
  final String close;
  final bool enabled;

  DaySchedule copyWith({String? open, String? close, bool? enabled}) =>
      DaySchedule(id: id, name: name, open: open ?? this.open, close: close ?? this.close, enabled: enabled ?? this.enabled);

  factory DaySchedule.fromJson(JsonReader r) {
    final open = normalizeTime(r.text('openTime'));
    final close = normalizeTime(r.text('closeTime'));
    return DaySchedule(
      id: r.integer('dayId') ?? 0,
      name: r.text('day'),
      open: open.isEmpty ? kDefaultOpen : open,
      close: close.isEmpty ? kDefaultClose : close,
      enabled: r.text('openClose') == '1',
    );
  }
}

class StoreProfile {
  const StoreProfile({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.landmark = '',
    this.latitude = '',
    this.longitude = '',
    this.joined = '',
    this.image = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.currency = '',
    this.deliveryTime = '',
    this.minimumAmount = '',
    this.minimumAmountFor = '',
    this.packagingEnabled = false,
    this.availabilityEnabled = false,
    this.days = const [],
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String landmark;
  final String latitude;
  final String longitude;
  final String joined;
  final String image;
  final String supportEmail;
  final String supportPhone;
  final String currency;
  final String deliveryTime;
  final String minimumAmount; // the average meal price
  final String minimumAmountFor; // for this many persons
  final bool packagingEnabled;
  final bool availabilityEnabled;
  final List<DaySchedule> days;

  factory StoreProfile.fromJson(JsonReader root) {
    final o = root.sub('data').sub('otherData');
    final days = o.list('arrTime', DaySchedule.fromJson)..sort((a, b) => a.id.compareTo(b.id));
    return StoreProfile(
      id: o.integer('id') ?? 0,
      name: o.text('name'),
      email: o.text('email'),
      phone: o.text('phone'),
      address: o.text('address'),
      landmark: o.text('landmark'),
      latitude: o.text('latitude'),
      longitude: o.text('longitude'),
      joined: o.text('joinedDate'),
      image: o.text('profileImage'),
      supportEmail: o.text('contactUsEmail'),
      supportPhone: o.sub('merchantDetails').text('phone'), // Jetpack: merchant_details.phone
      currency: o.text('currency'),
      deliveryTime: o.text('deliveryTime'),
      minimumAmount: o.text('minimumAmount'),
      minimumAmountFor: o.text('minimumAmountFor'),
      packagingEnabled: o.text('packagingPreferenceEnable') == '1',
      availabilityEnabled: o.text('productAvailabilityTimeModuleEnable') == '1',
      days: days,
    );
  }
}