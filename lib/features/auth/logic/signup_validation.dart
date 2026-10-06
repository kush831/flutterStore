import '../../splash/data/app_config.dart';

enum SignupField { store, segment, name, email, country, phone, password, confirm, sponsorName, sponsorEmail, terms }

class SignupForm {
  const SignupForm({
    required this.store,
    required this.segmentId,
    required this.name,
    required this.email,
    required this.country,
    required this.phone,
    required this.password,
    required this.confirm,
    this.sponsorName = '',
    this.sponsorEmail = '',
    this.agreed = false,
  });

  final String store;
  final String segmentId;
  final String name;
  final String email;
  final ConfigCountry? country;
  final String phone;
  final String password;
  final String confirm;
  final String sponsorName;
  final String sponsorEmail;
  final bool agreed;

  String get phoneDigits => phone.replaceAll(RegExp(r'\D'), '');
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// field → the server string KEY of the message to show (the controller turns keys into texts).
Map<SignupField, String> validateSignup(SignupForm f, {required bool sponsorRequired, required bool termsRequired}) {
  const required = 'common_formvalidation_required_error';
  final e = <SignupField, String>{};

  if (f.store.trim().isEmpty) e[SignupField.store] = 'storedetails_storeprofile_store_name_required';
  if (f.segmentId.isEmpty) e[SignupField.segment] = required;
  if (f.name.trim().isEmpty) e[SignupField.name] = required;

  final mail = f.email.trim();
  if (mail.isEmpty) {
    e[SignupField.email] = 'auth_loginscreen_email_required';
  } else if (!_email.hasMatch(mail)) {
    e[SignupField.email] = 'common_formvalidation_email_invalid_error';
  }

  final c = f.country;
  if (c == null) e[SignupField.country] = required;

  final digits = f.phoneDigits;
  if (digits.isEmpty) {
    e[SignupField.phone] = 'storedetails_storeprofile_phone_required';
  } else if (c != null && ((c.minPhone > 0 && digits.length < c.minPhone) || (c.maxPhone > 0 && digits.length > c.maxPhone))) {
    e[SignupField.phone] = 'common_formvalidation_phone_invalid_error';
  }

  if (f.password.isEmpty) e[SignupField.password] = 'auth_loginscreen_password_required';
  if (f.confirm.isEmpty) {
    e[SignupField.confirm] = required;
  } else if (f.confirm != f.password) {
    e[SignupField.confirm] = 'auth_signupscreen_passwordNotMatch';
  }

  if (sponsorRequired) {
    if (f.sponsorName.trim().isEmpty) e[SignupField.sponsorName] = required;
    if (f.sponsorEmail.trim().isEmpty) e[SignupField.sponsorEmail] = required;
  }
  if (termsRequired && !f.agreed) e[SignupField.terms] = 'auth_signupscreen_terms_required';
  return e;
}