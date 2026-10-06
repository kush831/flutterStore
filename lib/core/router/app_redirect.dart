import '../auth/auth_controller.dart';
import 'routes.dart';

/// Where a signed-in or signed-out user starts. The splash screen (Step 6) adds the
/// config checks (maintenance, update, membership) before using this.
String startRoute(AuthState a, {bool membership = false}) {
  if (!a.loggedIn) return Routes.welcome;
  return switch (a.signupStatus) {
    3 => Routes.stripeDocuments,
    4 => Routes.uploadDocuments,
    _ => membership ? Routes.membership : Routes.home,
  };
}

String startupRoute({
  required bool loggedIn,
  required int signupStatus,
  required bool membershipEnabled,
  required bool previewGate, // Preview flavor and the PIN was not entered yet
}) {
  if (!loggedIn) return previewGate ? Routes.login : Routes.welcome;
  return switch (signupStatus) {
    3 => Routes.stripeDocuments,
    4 => Routes.uploadDocuments,
    _ => membershipEnabled ? Routes.membership : Routes.home,
  };
}

const _authEntry = {
  Routes.welcome,
  Routes.login,
  Routes.signup,
  Routes.forgotPassword,
  Routes.verifyOtp,
  Routes.resetPassword,
  Routes.previewLogin,
  Routes.demoLogin,
};

/// The whole navigation policy in one pure function (unit-tested).
String? appRedirect({
  required String location, // path only
  required String fullLocation, // path + query, kept as `from` for deep links
  required AuthState auth,
  required bool devEnabled,
  bool membershipEnabled = false,
}) {
  // developer pages: closed in production
  if (location.startsWith('/dev')) {
    if (devEnabled) return null;
    return auth.loggedIn ? Routes.home : Routes.splash;
  }


  if (location == Routes.splash) return null; // the splash decides where to go
  if (location.startsWith('/cms/')) return null; // terms & privacy are open to everyone
  if ((location == Routes.previewLogin || location == Routes.demoLogin) && !devEnabled) {
    return auth.loggedIn ? Routes.home : Routes.welcome;
  }
  // ── signed out ─────────────────────────────────────────────────────────────
  if (!auth.loggedIn) {
    if (_authEntry.contains(location)) return null;
    if (!auth.returnToAfterLogin) return Routes.login;
    return Uri(path: Routes.login, queryParameters: {'from': fullLocation}).toString();
  }

  // ── signed in ──────────────────────────────────────────────────────────────
  if (_authEntry.contains(location)) {
    final from = Uri.parse(fullLocation).queryParameters['from'];
    if (auth.signupStatus == 0 && auth.returnToAfterLogin && _isSafeReturn(from)) return from;
    return startRoute(auth, membership: membershipEnabled);
  }

  final status = auth.signupStatus;
  if (status == 3 && location != Routes.stripeDocuments) return Routes.stripeDocuments;
  if (status == 4 && location != Routes.uploadDocuments) return Routes.uploadDocuments;
  if (status != 3 && location == Routes.stripeDocuments) return Routes.home;
  if (status != 4 && location == Routes.uploadDocuments) return Routes.home;
  return null;

}
/// Only an in-app path may be used as the "go back to" target (never //evil.com or a full URL).
bool _isSafeReturn(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return false;
  final path = Uri.parse(from).path;
  return path != Routes.splash && !_authEntry.contains(path) && !path.startsWith('/dev');
}
