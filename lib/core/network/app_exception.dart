enum ErrorKind { network, timeout, server, api, session, cancelled, unknown }

/// The only error type repositories throw.
/// Until Step 4 the default messages are English; Step 4 maps them to the dynamic strings.
class AppException implements Exception {
  const AppException(this.message, {this.kind = ErrorKind.unknown, this.code, this.statusCode, this.detail});

  /// Safe to show to the user. For [ErrorKind.api] it is the server's own (already translated) message.
  final String message;
  final ErrorKind kind;

  /// The API's `result` value ("0", "999" …).
  final String? code;
  final int? statusCode;

  /// Technical detail for developers (never shown to users).
  final String? detail;

  bool get isNetwork => kind == ErrorKind.network || kind == ErrorKind.timeout;
  bool get isSession => kind == ErrorKind.session;

  static const noInternet = 'No internet connection. Check your network and try again.';
  static const timedOut = 'The request timed out. Please try again.';
  static const serverProblem = 'Something went wrong on our side. Please try again.';
  static const generic = 'Something went wrong. Please try again.';

  /// For any caught object: the message to show.
  static String messageOf(Object error) => error is AppException ? error.message : generic;

  @override
  String toString() => 'AppException($kind, $message${code != null ? ', code=$code' : ''})';
}