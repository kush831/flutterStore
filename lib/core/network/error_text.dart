import '../strings/app_strings.dart';
import 'app_exception.dart';

/// The text to show for any caught error.
///  • the server refused with a message → that message (already in the user's language)
///  • no connection / timeout           → "Connection Failed"
///  • anything else                     → "Something went wrong"
String errorText(Object error, AppStrings s) {
  if (error is AppException) {
    if (error.kind == ErrorKind.api && error.message.trim().isNotEmpty) return error.message;
    if (error.isNetwork) return s.get('common_allscreen_connectionFailed');
  }
  return s.get('common_allscreen_something_went_wrong');
}