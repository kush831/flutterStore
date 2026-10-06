import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/core/auth/auth_controller.dart';
import 'package:apporio_store_30sept/core/router/app_redirect.dart';

String? go(String loc, AuthState a, {bool dev = true}) =>
    appRedirect(location: Uri.parse(loc).path, fullLocation: loc, auth: a, devEnabled: dev);

void main() {
  const out = AuthState();
  const inn = AuthState(loggedIn: true);

  test('signed-out users are sent to login and the wanted page is remembered', () {
    expect(go('/orders/12', out), '/login?from=%2Forders%2F12');
  });

  test('after an explicit sign-out the next user starts fresh', () {
    expect(go('/orders', const AuthState(returnToAfterLogin: false)), '/login');
  });

  test('public pages stay open when signed out', () {
    expect(go('/login', out), isNull);
    expect(go('/signup', out), isNull);
    expect(go('/cms/terms', out), isNull);
    expect(go('/', out), isNull);
  });

  test('signed-in users skip the auth screens', () {
    expect(go('/login', inn), '/home');
    expect(go('/welcome', inn), '/home');
  });

  test('signup status gates the app', () {
    const s3 = AuthState(loggedIn: true, signupStatus: 3);
    const s4 = AuthState(loggedIn: true, signupStatus: 4);
    expect(go('/orders', s3), '/stripe-documents');
    expect(go('/stripe-documents', s3), isNull);
    expect(go('/home', s4), '/upload-documents');
    expect(go('/stripe-documents', inn), '/home'); // nothing left to submit
    expect(go('/login', s3), '/stripe-documents');
  });

  test('developer pages are closed in production', () {
    expect(go('/dev', inn, dev: false), '/home');
    expect(go('/dev', out, dev: false), '/');
    expect(go('/dev', out), isNull);
  });
}