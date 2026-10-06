import '../../../core/network/json_reader.dart';

class LoginResult {
  const LoginResult({
    required this.token,
    this.signupStatus = 0,
    this.membershipEnabled = false,
    this.subscriptionActive = false,
    this.segment = '',
    this.storeId = '',
    this.message = '',
  });

  final String token;

  /// 0 = fine · 3 = Stripe documents required · 4 = upload documents required.
  final int signupStatus;
  final bool membershipEnabled;
  final bool subscriptionActive;

  /// "food", "grocery" …
  final String segment;
  final String storeId;
  final String message;

  /// Jetpack sent every membership store to the membership page. The server also tells us whether
  /// the subscription is already active, so only stores that really need to subscribe go there.
  bool get membershipNeeded => membershipEnabled && !subscriptionActive;

  factory LoginResult.fromJson(JsonReader root) {
    final data = root.sub('data');
    final other = data.sub('otherData');
    return LoginResult(
      token: data.text('accessToken'),
      signupStatus: other.integer('signupStatus') ?? 0,
      membershipEnabled: other.flag('isMembershipEnable'),
      subscriptionActive: other.sub('subscriptionDetails').flag('isActive'),
      segment: other.text('segment'),
      storeId: other.str('id') ?? '',
      message: root.text('message'),
    );
  }
}