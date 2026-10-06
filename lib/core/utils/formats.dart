/// Values sent to the API must NEVER follow the phone's language.
/// Jetpack used the device locale, so an Arabic phone sent "٢٠٢٦-٠٩-٠١" and the server returned nothing.
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String apiTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';